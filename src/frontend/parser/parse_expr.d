module frontend.parser.parse_expr;
import frontend;

mixin template ParseExpr()
{
    Node parseExpression(Precedence precedence = Precedence.LOWEST)
    {
        Node left = this.parsePrefix();

        if (left is null)
            return null;

        while (!this.isAtEnd() && precedence < this.peekPrecedence())
        {
            ulong oldPos = this.pos;

            this.infix(left);
            if (this.pos == oldPos)
                break;
        }

        return left;
    }

    Node parsePrefix()
    {
        Token token = this.advance();

        switch (token.kind)
        {
        case TokenKind.I32:
            return new IntLit(to!int(token.value.get!string), token.loc);

        case TokenKind.I64:
            return new LongLit(to!long(token.value.get!string), token.loc);

        case TokenKind.F32:
            return new FloatLit(to!float(token.value.get!string), token.loc);

        case TokenKind.F64:
            return new DoubleLit(to!double(token.value.get!string), token.loc);

        case TokenKind.String:
            return new StringLit(token.value.get!string, token.loc);

        case TokenKind.Char:
            return new CharLit(to!char(token.value.get!string), token.loc);

        case TokenKind.True:
            return new BoolLit(true, token.loc);

        case TokenKind.False:
            return new BoolLit(false, token.loc);

        case TokenKind.Null:
            return new NullLit(token.loc);

        case TokenKind.Identifier:
            return this.parseIdentifierExpr(token);

        case TokenKind.LParen:
            return this.parseGroupedExpr();

        case TokenKind.LBracket:
            return this.parseArrayLiteral();

        case TokenKind.Bang:
        case TokenKind.Minus:
        case TokenKind.Plus:
        case TokenKind.Star:
        case TokenKind.BitAnd:
            return this.parseUnaryExpr(token);
        
        case TokenKind.Sizeof:
            return this.parseSizeofExpr();

        case TokenKind.PlusPlus:
        case TokenKind.MinusMinus:
            return this.parsePrefixIncDec(token);

        default:
            reportError("Unknown token in expression: '" ~ to!string(token.value) ~ "'", token
                    .loc);
            return null;
        }
    }

    SizeOfExpr parseSizeofExpr()
    {
        Loc start = this.previous().loc;
        Node value = null;
        TypeExpr type = null;

        if (this.check(TokenKind.Identifier))
        {
            string id = this.peek().value.get!string;
            if (registry.typeExists(id))
                type = this.parseType();
        }

        if (type is null)
            value = this.parseExpression();

        return new SizeOfExpr(value, type, this.getLoc(start, this.previous().loc));
    }

    TernaryExpr parseTernary(Node left)
    {
        this.advance(); // pula o ?
        Node trueExpr = null;
        Node falseExpr = null;
        // elvis?
        // verdadeiro ?: "tome"
        if (this.match([TokenKind.Colon]))
            falseExpr = this.parseExpression();
        else
        {
            // verdadeiro ? trueExpr : falseExpr
            trueExpr = this.parseExpression();
            this.consume(TokenKind.Colon, "Expected ':' after the true ternary.");
            falseExpr = this.parseExpression();
        }
        return new TernaryExpr(left, trueExpr, falseExpr, this.getLoc(left.loc, falseExpr.loc));
    }

    BinaryExpr parseBinaryExpr(Node left)
    {
        Token op = this.advance();
        Node right = this.parseExpression(this.getPrecedence(op.kind));

        if (right is null)
        {
            reportError("Expected expression after operator '" ~ op.value.get!string ~ "'", op.loc);
            return null;
        }

        return new BinaryExpr(left, right, op.value.get!string,
            this.getLoc(left.loc, right.loc));
    }

    AssignDecl parseAssignDecl(Node left)
    {
        // Valida que o lado esquerdo pode receber atribuição
        if (!this.isValidAssignTarget(left))
        {
            left.print();
            reportError("Invalid left side for assignment.", left.loc);
            return null;
        }

        Token op = this.advance();
        Node right = this.parseExpression(Precedence.ASSIGN);

        if (right is null)
        {
            reportError("Expected expression after '" ~ op.value.get!string ~ "'", op.loc);
            return null;
        }

        return new AssignDecl(left, right, op.value.get!string,
            this.getLoc(left.loc, right.loc));
    }

    UnaryExpr parseUnaryExpr(Token op)
    {
        Loc start = op.loc;
        Node operand = this.parseExpression(Precedence.HIGHEST);

        if (operand is null)
        {
            reportError("Expected expression after operator '" ~ op.value.get!string ~ "'", op.loc);
            return null;
        }

        TypeExpr type = operand.type;
        string ope = op.value.get!string;
        if (ope == "&")
            type = new PointerTypeExpr(type, type.loc);

        return new UnaryExpr(operand, type, ope, this.getLoc(start, operand.loc));
    }

    Node parseIdentifierExpr(Token name)
    {
        string id = name.value.get!string;

        // Verifica se é uma struct seguida de { ou (
        if (registry.typeExists(id))
        {
            // User(...) - chamada de construtor
            if (this.check(TokenKind.LParen))
                return this.parseStructLit(id, name.loc, true);

            // User{...} - inicialização literal
            if (this.check(TokenKind.LBrace))
                return this.parseStructLit(id, name.loc, false);
        }

        return new Identifier(id, name.loc);
    }

    StructLit parseStructLit(string structName, Loc start, bool isConstructorCall)
    {
        StructFieldInit[] fieldInits;
        bool isPositional = true;

        if (isConstructorCall)
        {
            // User("John", 25) - construtor
            this.advance(); // consome '('

            if (!this.check(TokenKind.RParen))
            {
                uint position = 0;
                do
                {
                    Node value = this.parseExpression(Precedence.LOWEST);
                    if (value is null)
                    {
                        reportError("Invalid argument in constructor call.", this.peek().loc);
                        // Recupera até vírgula ou fecha parênteses
                        while (!this.isAtEnd() && !this.check(TokenKind.Comma) && 
                               !this.check(TokenKind.RParen))
                            this.advance();
                        if (this.check(TokenKind.Comma))
                            continue;
                        break;
                    }

                    fieldInits ~= StructFieldInit("", value, position++, value.loc);
                }
                while (this.match([TokenKind.Comma]));
            }

            Loc end = this.consume(TokenKind.RParen, 
                "Expected ')' after constructor arguments.").loc;

            return new StructLit(structName, fieldInits, true, 
                                 this.getLoc(start, end), true);
        }
        else
        {
            // User{...} - literal
            this.advance(); // consome '{'

            if (!this.check(TokenKind.RBrace))
            {
                // Detecta se é posicional ou nomeado no primeiro elemento
                bool firstElem = true;
                uint position = 0;

                do
                {
                    // Verifica se é nomeado (.name = value)
                    if (this.check(TokenKind.Dot))
                    {
                        if (firstElem)
                            isPositional = false;
                        else if (isPositional)
                        {
                            reportError("Cannot mix positional and named initialization.", 
                                       this.peek().loc);
                            return null;
                        }

                        this.advance(); // consome '.'
                        Token fieldName = this.consume(TokenKind.Identifier, 
                            "Expected field name after '.'");
                        this.consume(TokenKind.Equals, 
                            "Expected '=' after field name.");

                        Node value = this.parseExpression(Precedence.LOWEST);
                        if (value is null)
                        {
                            reportError("Invalid value for field '" ~ 
                                       fieldName.value.get!string ~ "'", 
                                       fieldName.loc);
                            // Recupera
                            while (!this.isAtEnd() && !this.check(TokenKind.Comma) && 
                                   !this.check(TokenKind.RBrace))
                                this.advance();
                            if (this.check(TokenKind.Comma))
                                continue;
                            break;
                        }

                        fieldInits ~= StructFieldInit(fieldName.value.get!string, 
                                                       value, 0, fieldName.loc);
                    }
                    // Inicialização posicional
                    else
                    {
                        if (!firstElem && !isPositional)
                        {
                            reportError("Cannot mix positional and named initialization.", 
                                       this.peek().loc);
                            return null;
                        }

                        Node value = this.parseExpression(Precedence.LOWEST);
                        if (value is null)
                        {
                            reportError("Invalid value in struct literal.", 
                                       this.peek().loc);
                            // Recupera
                            while (!this.isAtEnd() && !this.check(TokenKind.Comma) && 
                                   !this.check(TokenKind.RBrace))
                                this.advance();
                            if (this.check(TokenKind.Comma))
                                continue;
                            break;
                        }

                        fieldInits ~= StructFieldInit("", value, position++, value.loc);
                    }

                    firstElem = false;
                }
                while (this.match([TokenKind.Comma]));
            }

            Loc end = this.consume(TokenKind.RBrace, 
                "Expected '}' after struct fields.").loc;

            return new StructLit(structName, fieldInits, isPositional, 
                                 this.getLoc(start, end), false);
        }
    }

    bool isEmptyStructLit()
    {
        return this.check(TokenKind.RBrace);
    }

    Node parseCastExpr(Loc start)
    {
        TypeExpr target = this.parseType();
        this.consume(TokenKind.RParen, "Expected ')' after the type.");
        Node from = this.parseExpression();
        return new CastExpr(target, from, this.getLoc(start, from.loc));
    }

    Node parseGroupedExpr()
    {
        Loc start = this.previous().loc;

        if (this.check(TokenKind.Identifier))
        {
            string id = this.peek().value.get!string;
            if (registry.typeExists(id))
            {
                // writeln("ID: ", id);
                // this.peek().print();
                return this.parseCastExpr(start);
            }
        }

        Node expr = this.parseExpression(Precedence.LOWEST);

        if (expr is null)
        {
            reportError("Expected expression within parentheses", start);
            return null;
        }

        this.consume(TokenKind.RParen, "Expected ')' after expression");
        return expr;
    }

    ArrayLit parseArrayLiteral()
    {
        Loc start = this.previous().loc;
        Node[] elements;

        if (!this.check(TokenKind.RBracket))
        {
            do
            {
                Node elem = this.parseExpression(Precedence.LOWEST);
                if (elem is null)
                {
                    reportError("Invalid expression in array literal.", this.peek().loc);
                    // Tenta recuperar pulando até vírgula ou colchete
                    while (!this.isAtEnd() && !this.check(TokenKind.Comma) && !this.check(
                            TokenKind.RBracket))
                        this.advance();
                    if (this.check(TokenKind.Comma))
                        continue;
                    break;
                }
                elements ~= elem;
            }
            while (this.match([TokenKind.Comma]));
        }

        Loc end = this.consume(TokenKind.RBracket, "Expected ']' after array elements.").loc;
        return new ArrayLit(elements, this.getLoc(start, end));
    }

    CallExpr parseCallExpr(Node callee)
    {
        Loc start = this.advance().loc; // consome '('
        Node[] args;

        // Extrai o nome da função se for um Identifier
        string funcName = "";
        if (auto id = cast(Identifier) callee)
            funcName = id.value.get!string;

        if (!this.check(TokenKind.RParen))
        {
            do
            {
                Node arg = this.parseExpression(Precedence.LOWEST);
                if (arg is null)
                {
                    reportError("Invalid argument in function call.", this.peek().loc);
                    // Tenta recuperar
                    while (!this.isAtEnd() && !this.check(TokenKind.Comma) && !this.check(
                            TokenKind.RParen))
                        this.advance();
                    if (this.check(TokenKind.Comma))
                        continue;
                    break;
                }
                args ~= arg;
            }
            while (this.match([TokenKind.Comma]));
        }

        this.consume(TokenKind.RParen, "Expected ')' after arguments.");
        return new CallExpr(callee, args, this.getLoc(callee.loc, this.previous().loc));
    }

    IndexExpr parseIndexExpr(Node target)
    {
        this.advance(); // consome '['
        Node index = this.parseExpression(Precedence.LOWEST);

        if (index is null)
        {
            reportError("Expected index expression", this.previous().loc);
            return null;
        }

        this.consume(TokenKind.RBracket, "Expected ']' after index");
        return new IndexExpr(target, index, this.getLoc(target.loc, this.previous().loc));
    }

    MemberExpr parseMemberExpr(Node target)
    {
        this.advance(); // consome '.'
        Token member = this.consume(TokenKind.Identifier, "Expected member's name after '.'");

        if (member.kind != TokenKind.Identifier)
            return null;

        return new MemberExpr(target, member.value.get!string,
            this.getLoc(target.loc, member.loc));
    }

    UnaryExpr parsePrefixIncDec(Token op)
    {
        Loc start = op.loc;
        Node operand = this.parseExpression(Precedence.HIGHEST);

        if (operand is null)
        {
            reportError("Expected expression after '" ~ op.value.get!string ~ "'", op.loc);
            return null;
        }

        // Valida que o operando pode ser incrementado/decrementado
        if (!this.isValidIncDecTarget(operand))
        {
            reportError("Invalid operand for " ~ op.value.get!string, operand.loc);
            return null;
        }

        return new UnaryExpr(operand, operand.type, op.value.get!string ~ "_prefix",
            this.getLoc(start, operand.loc));
    }

    UnaryExpr parsePostfixIncDec(Node operand)
    {
        // Valida que o operando pode ser incrementado/decrementado
        if (!this.isValidIncDecTarget(operand))
        {
            reportError("Invalid operand for increment/decrement", operand.loc);
            return null;
        }

        Token op = this.advance();
        return new UnaryExpr(operand, operand.type, op.value.get!string ~ "_postfix",
            this.getLoc(operand.loc, op.loc));
    }

    // Funções auxiliares de validação
    private bool isValidAssignTarget(Node node)
    {
        // Só identifiers, índices e membros podem receber atribuição
        return cast(Identifier) node !is null
            || cast(IndexExpr) node !is null
            || cast(UnaryExpr) node !is null
            || cast(MemberExpr) node !is null;
    }

    private bool isValidIncDecTarget(Node node)
    {
        // Mesma regra que atribuição
        return this.isValidAssignTarget(node);
    }

    void infix(ref Node left)
    {
        switch (this.peek().kind)
        {
            // Operadores binários aritméticos
        case TokenKind.Plus:
        case TokenKind.Minus:
        case TokenKind.Star:
        case TokenKind.Slash:
        case TokenKind.Modulo:

            // Operadores lógicos
        case TokenKind.And:
        case TokenKind.Or:

            // Operadores bitwise
        case TokenKind.BitAnd:
        case TokenKind.BitOr:
        case TokenKind.BitXor:
        case TokenKind.BitSHL:
        case TokenKind.BitSHR:
        case TokenKind.BitSAR:

            // Operadores de comparação
        case TokenKind.EqualsEquals:
        case TokenKind.NotEquals:
        case TokenKind.GreaterThan:
        case TokenKind.GreaterThanEquals:
        case TokenKind.LessThan:
        case TokenKind.LessThanEquals:
        case TokenKind.TildeEquals:
            left = this.parseBinaryExpr(left);
            return;

            // Operadores de atribuição
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
            left = this.parseAssignDecl(left);
            return;

            // Chamada de função
        case TokenKind.LParen:
            left = this.parseCallExpr(left);
            return;

            // Acesso a índice/subscript
        case TokenKind.LBracket:
            left = this.parseIndexExpr(left);
            return;

            // Acesso a membro
        case TokenKind.Dot:
            left = this.parseMemberExpr(left);
            return;

        case TokenKind.Question:
            left = this.parseTernary(left);
            return;

            // Pós-incremento/decremento
        case TokenKind.PlusPlus:
        case TokenKind.MinusMinus:
            left = this.parsePostfixIncDec(left);
            return;

        default:
            return;
        }
    }
}
