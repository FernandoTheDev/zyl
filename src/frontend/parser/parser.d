module frontend.parser.parser;
import frontend, common.reporter;

enum Precedence
{
    LOWEST = 1,
    ASSIGN = 2, // =, +=, -=, |=, &=, <<=, >>=
    EQUALS = 3, // ==, !=
    OR = 4, // ||
    AND = 5, // &&
    BIT_OR = 6, // |
    BIT_XOR = 7, // ^
    BIT_AND = 8, // &
    SUM = 9, // +, -
    MUL = 10, // *, /
    BIT_SHIFT = 11, // <<, >>
    CALL = 12, // funções, index
    HIGHEST = 13,
}

class Parser
{
private:
    Token[] tokens;
    ulong pos = 0; // offset
    DiagnosticError error;
    TypeRegistry registry;
    bool[string] modulesCache;
    string pathRoot;

    pragma(inline, true)
    void reportError(string message, Loc loc, Suggestion[] suggestions = null)
    {
        error.addError(Diagnostic(message, loc, suggestions));
    }

    pragma(inline, true)
    void reportWarning(string message, Loc loc, Suggestion[] suggestions = null)
    {
        error.addWarning(Diagnostic(message, loc, suggestions));
    }

    mixin ParseDecl!();
    mixin ParseExpr!();
    mixin ParseStmt!();
    mixin ParseType!();

    Node parseFuncOrVar()
    {
        TypeExpr type = this.parseType();
        Token id;
        
        if (this.check(TokenKind.String))
            id = this.advance();
        else
            id = this.consume(TokenKind.Identifier, "An identifier is expected after the type.");

        if (this.check(TokenKind.SemiColon) || this.check(TokenKind.Equals))
            return this.parseVarDecl(type, id);

        if (this.check(TokenKind.LParen))
            return this.parseFuncDecl(type, id);

        writeln(type.toStr());
        id.print();
        throw new Exception("ERRRORRRR.");
    }

    Node parse()
    {
        immutable ulong startPos = this.pos;

        if (this.match([TokenKind.SemiColon]))
            if (!this.check(TokenKind.RBrace))
                return parse();
        
        if (this.check(TokenKind.Identifier))
        {
            Token tk = this.peek();
            string id = tk.value.get!string;

            // forma semantica conhecida
            bool isKnownType = registry.typeExists(id) || registry.typePreExists(id);

            // heuristica
            // Nova Lógica (Heurística)
            // Se já conhecemos, ótimo. Se não, usamos a heurística visual.
            if ((isKnownType || looksLikeDeclaration()) && this.future(2).kind != TokenKind.Bang)
                 // É seguro chamar parseFuncOrVar agora.
                 // Mesmo que o tipo não exista no registry, o parseType() vai criar um NamedTypeExpr
                 // e o Semantic vai validar depois.
                 return this.parseFuncOrVar();
            
            // template?
            // pattern: ID ID !
            // o proximo token é um ID?
            if (this.future().kind == TokenKind.Identifier && this.future(2).kind == TokenKind.Bang)
            {
                this.advance();
                // is a template
                // if (!registry.typeExists(id))
                //     registry.registerType(id, new StructType(id, fields, methods)); // registra uma base temporariamente
                Token name = this.advance();
                this.advance(); // skip '!'
                TypeExpr[] types; // [T, U, V, ...]
                // ID ID ! ID () {}
                if (this.check(TokenKind.Identifier))
                    types ~= new NamedTypeExpr(this.advance().value.get!string, this.previous().loc);
                // ID ID ! (ID, ...) () {}
                else if (this.match([TokenKind.LParen]))
                {
                    while (!this.match([TokenKind.RParen]) && !this.isAtEnd())
                    {
                        string t = this.consume(TokenKind.Identifier, 
                            "An identifier is expected for template type name.").value.get!string;
                        types ~= new NamedTypeExpr(t, this.previous().loc);
                        this.match([TokenKind.Comma]);
                    }
                    // end
                    foreach (TypeExpr ty; types)
                        if (!registry.typeExists(ty.toStr()))
                            registry.registerType(ty.toStr(), new PrimitiveType(BaseType.Void));
                }
                FuncDecl fn = this.parseFuncDecl(new NamedTypeExpr(id, tk.loc), name);
                fn.templateType = types;
                fn.isTemplate = true;
                // remove os tipos adicionados
                foreach (TypeExpr ty; types)
                    registry.unregisterType(ty.toStr());
                return fn;
            }
        }

        if (this.isDeclaration())
           {
               if (auto node = this.parseDeclaration())
               {
                this.match([TokenKind.SemiColon]);
                return node;
            }
            this.pos = startPos;
        }

        if (auto node = this.parseStatement())
        {
            this.match([TokenKind.SemiColon]);
            return node;
        }

        this.pos = startPos;

        if (auto node = this.parseExpression())
        {
            this.match([TokenKind.SemiColon]);
            return node;
        }

        throw new Exception("Error parsing.");
    }

    bool isDeclaration()
    {
        Token current = this.peek();
        switch (current.kind)
        {
        case TokenKind.Type:
        case TokenKind.Struct:
        case TokenKind.Enum:
        case TokenKind.Union:
            return true;
        default:
            return false;
        }
    }

    pragma(inline, true);
    bool isAtEnd()
    {
        return this.peek().kind == TokenKind.Eof;
    }

    Variant next()
    {
        if (this.isAtEnd())
            return Variant(false);
        return Variant(this.tokens[this.pos + 1]);
    }

    pragma(inline, true);
    Token peek()
    {
        return this.tokens[this.pos];
    }

    pragma(inline, true);
    Token previous(ulong i = 1)
    {
        return this.tokens[this.pos - i];
    }

    pragma(inline, true);
    Token future(ulong i = 1)
    {
        return this.tokens[this.pos + i];
    }

    Token advance()
    {
        if (!this.isAtEnd())
            this.pos++;
        return this.previous();
    }

    bool match(TokenKind[] kinds)
    {
        foreach (kind; kinds)
        {
            if (this.check(kind))
            {
                this.advance();
                return true;
            }
        }
        return false;
    }

    bool check(TokenKind kind)
    {
        if (this.isAtEnd())
            return false;
        return this.peek().kind == kind;
    }

    Token consume(TokenKind expected, string message)
    {
        if (this.check(expected))
            return this.advance();
        reportError(format("Parsing error: %s", message), this.peek().loc);
        throw new Exception(format("Parsing error: %s", message));
    }

    Precedence getPrecedence(TokenKind kind)
    {
        switch (kind)
        {
        case TokenKind.Equals:
        case TokenKind.PlusEquals:
        case TokenKind.MinusEquals:
        case TokenKind.StarEquals:
        case TokenKind.SlashEquals:
        case TokenKind.ModuloEquals:
        case TokenKind.BitAndEquals:
        case TokenKind.BitOrEquals:
        case TokenKind.BitXorEquals:
        case TokenKind.BitSHLEquals:
        case TokenKind.BitSHREquals:
        case TokenKind.TildeEquals:
        case TokenKind.Or:
        case TokenKind.And:
            return Precedence.ASSIGN;

        case TokenKind.EqualsEquals:
        case TokenKind.NotEquals:
        case TokenKind.GreaterThan:
        case TokenKind.LessThan:
        case TokenKind.LessThanEquals:
        case TokenKind.GreaterThanEquals:
            return Precedence.EQUALS;

        case TokenKind.BitOr:
            return Precedence.BIT_OR;
        case TokenKind.BitXor:
            return Precedence.BIT_XOR;
        case TokenKind.BitAnd:
            return Precedence.BIT_AND;

        case TokenKind.Plus:
        case TokenKind.Minus:
        case TokenKind.PlusPlus:
        case TokenKind.MinusMinus:
        case TokenKind.Question:
            return Precedence.SUM;

        case TokenKind.Star:
        case TokenKind.Slash:
        case TokenKind.Modulo:
            return Precedence.MUL;

        case TokenKind.BitSHL:
        case TokenKind.BitSHR:
        case TokenKind.BitSAR:
            return Precedence.BIT_SHIFT;

        case TokenKind.LParen:
        case TokenKind.LBracket:
        case TokenKind.Dot:
            return Precedence.CALL;

        default:
            return Precedence.LOWEST;
        }
    }

    pragma(inline, true);
    Precedence peekPrecedence()
    {
        return this.getPrecedence(this.peek().kind);
    }

    pragma(inline, true);
    Loc getLoc(ref Loc start, ref Loc end)
    {
        return Loc(start.filename, start.dir, start.start, end.end);
    }

    // Heurística poderosa para identificar declarações sem Semantic Registry
    bool looksLikeDeclaration()
    {
        // Começa olhando o token atual (offset 0)
        ulong offset = 0;
        
        // 1. Uma declaração deve começar com um Identificador (o nome do Tipo base)
        if (this.future(offset).kind != TokenKind.Identifier) return false;
        offset++;

        // 2. Loop para consumir sufixos de tipo (*, [], !, .)
        while (true)
        {
            Token t = this.future(offset);

            // Acesso a módulo: std.io (ID . ID)
            if (t.kind == TokenKind.Dot)
            {
                offset++;
                if (this.future(offset).kind != TokenKind.Identifier) return false;
                offset++;
                continue;
            }

            // Template: List!int ou DynArray!(T)
            if (t.kind == TokenKind.Bang)
            {
                offset++; // Consome '!'
                Token next = this.future(offset);
                
                // Se for parenteses: !(...)
                if (next.kind == TokenKind.LParen)
                {
                    offset++; 
                    long depth = 1;
                    // Avança até fechar os parenteses balanceados
                    while (depth > 0)
                    {
                        Token tk = this.future(offset);
                        if (tk.kind == TokenKind.Eof) return false;
                        if (tk.kind == TokenKind.LParen) depth++;
                        else if (tk.kind == TokenKind.RParen) depth--;
                        offset++;
                    }
                }
                // Se for identificador direto: !int
                else if (next.kind == TokenKind.Identifier || 
                         next.kind == TokenKind.I32 || next.kind == TokenKind.Type) // Ajuste conforme seus tokens de tipo primitivo
                {
                    offset++;
                }
                else 
                {
                    // Sintaxe de template inválida ou complexa demais para heurística
                    // Mas vamos assumir que pode ser um tipo e continuar
                }
                continue;
            }

            // Ponteiro: int* ou int**
            if (t.kind == TokenKind.Star)
            {
                offset++;
                continue;
            }

            // Array: int[] ou int[10]
            if (t.kind == TokenKind.LBracket)
            {
                offset++;
                long depth = 1;
                while (depth > 0)
                {
                    Token tk = this.future(offset);
                    if (tk.kind == TokenKind.Eof) return false;
                    if (tk.kind == TokenKind.LBracket) depth++;
                    else if (tk.kind == TokenKind.RBracket) depth--;
                    offset++;
                }
                continue;
            }

            // Se chegou aqui, não é mais parte do Tipo. Sai do loop.
            break;
        }

        // 3. O Momento da Verdade:
        // Se o que vem depois de toda essa "salada de tipos" for um IDENTIFICADOR,
        // então é uma declaração: Tipo NomeDaVariavel;
        Token afterType = this.future(offset);
        
        if (afterType.kind == TokenKind.Identifier)
        {
            return true;
        }

        return false;
    }

public:
    this(Token[] tokens = [], DiagnosticError error, TypeRegistry registry, string pathRoot)
    {
        this.error = error;
        this.tokens = tokens;
        this.registry = registry;
        this.pathRoot = pathRoot;
    }

    Program parseProgram()
    {
        Program program = new Program([]);
        try
        {
            while (!this.isAtEnd())
                program.body ~= this.parse();
            if (this.tokens.length == 0)
                return program;
        }
        catch (Exception e)
            throw e; // propaga
        return program;
    }
}
