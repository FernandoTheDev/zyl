module frontend.parser.parse_decl;
import frontend;

mixin template ParseDecl()
{
    Node parseDeclaration()
    {
        switch (this.peek().kind)
        {
        case TokenKind.Type:
            return this.parseTypeDecl();

        case TokenKind.Struct:
            return this.parseStructDecl();

        case TokenKind.Enum:
            return this.parseEnumDecl();

        case TokenKind.Union:
            return this.parseUnionDecl();

        default:
            reportError("Unrecognized statement.", this.peek().loc);
            return null;
        }
    }

    Node parseEnumDecl()
    {
        Loc start = advance().loc;
        
        Token idToken = this.consume(TokenKind.Identifier, "Expected an identifier for enum name.");
        string id = idToken.value.get!string;
        bool noMangle;

        if (this.match([TokenKind.NoMangle]))
            noMangle = true;
        
        this.consume(TokenKind.LBrace, "Expected '{' after enum name.");
        
        int[string] members;
        int currentValue = 0; // Contador automático para valores implícitos

        while (!this.check(TokenKind.RBrace) && !this.isAtEnd())
        {
            Token memberId = this.consume(TokenKind.Identifier, "Expected enum member name.");
            string memberName = memberId.value.get!string;
            
            if (this.match([TokenKind.Equals]))
            {
                Node expr = this.parseExpression();    
                if (auto intLit = cast(IntLit) expr)
                    currentValue = intLit.value.get!int;
                else
                    reportError("Enum member value must be an integer literal.", expr.loc);
            }
            
            members[memberName] = currentValue;
            currentValue++; // Prepara para o próximo (auto-incremento)
            
            // Consome vírgula opcional (permite trailing comma)
            this.match([TokenKind.Comma]);
        }
        
        this.consume(TokenKind.RBrace, "Expected '}' after enum body.");
        
        if (!registry.typeExists(id))
            registry.registerType(id, new EnumType(id, members));
            
        return new EnumDecl(id, members, this.getLoc(start, this.previous().loc), noMangle);
    }

    Node parseUnionDecl()
    {
        Loc start = advance().loc; // consome 'union'
        string id = this.consume(TokenKind.Identifier, "Expected an identifier for union name.").value.get!string;
        bool noMangle;

        if (this.match([TokenKind.NoMangle]))
            noMangle = true;
    
        StructField[] fields;
        
        if (!registry.typeExists(id))
            registry.registerType(id, new UnionType(id, fields)); 
            
        this.consume(TokenKind.LBrace, "Expected '{' after union name.");
        while (!this.isAtEnd() && !this.check(TokenKind.RBrace))
        {
            Node node = this.parse();
            if (node.kind == NodeKind.VarDecl)
            {
                VarDecl var = cast(VarDecl) node;
                fields ~= StructField(var.id, var.type, var.resolvedType, var.value.get!Node, var.loc);
                continue;
            }
            reportError("Only field declarations are allowed inside a union.", node.loc);
        }

        this.consume(TokenKind.RBrace, "Expected '}' after union body.");
        return new UnionDecl(id, fields, this.getLoc(start, this.previous().loc), noMangle);
    }

    StructDecl parseStructDecl()
    {
        // struct User { string name; int age = 17; User next = null; }
        Loc start = advance().loc;
        string id = this.consume(TokenKind.Identifier, "Expected an identifier to struct name.").value.get!string;
        bool noMangle;

        if (this.match([TokenKind.NoMangle]))
            noMangle = true;

        StructField[] fields;
        StructMethod[][string] methods;
        // precisa criar um tipo do usuario temporariamente pra conseguir identificar isso como uma struct
        // o typeresolver corrigirá isso no futuro
        if (!registry.typeExists(id))
            registry.registerType(id, new StructType(id, fields, methods)); // registra uma base temporariamente

        TypeExpr[] types; // [T, U, V, ...]
        if (this.match([TokenKind.Bang]))
        {
            // struct ID ! ID {}
            if (this.check(TokenKind.Identifier))
                types ~= new NamedTypeExpr(this.advance().value.get!string, this.previous().loc);
            // struct ID ! (ID, ...) {}
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
            }
            foreach (TypeExpr ty; types)
                if (!registry.typeExists(ty.toStr()))
                    registry.registerType(ty.toStr(), new PrimitiveType(BaseType.Void));
        }

        this.consume(TokenKind.LBrace, "Expected '{' after struct name.");

        // o corpo é basicamente composto por declarações de variaveis e de declarações de funções
        while (!this.isAtEnd() && !this.check(TokenKind.RBrace))
        {
            // faz o parse do node a vista
            Node node = this.parse();

            // converte ou dá erro
            if (node.kind == NodeKind.VarDecl)
            {
                // vai virar um field
                VarDecl var = cast(VarDecl) node;
                fields ~= StructField(var.id, var.type, var.resolvedType, var.value.get!Node, var.loc);
                continue;
            } else if (node.kind == NodeKind.FuncDecl)
            {
                // vai virar um método
                FuncDecl func = cast(FuncDecl) node;
                methods[func.name] ~= StructMethod(func, func.name == "this", func.loc);
                continue;
            }

            reportError("You can't use that inside the struct.", node.loc);
        }

        foreach (TypeExpr ty; types)
            registry.unregisterType(ty.toStr());

        this.consume(TokenKind.RBrace, "Expected '}' after struct body.");
        StructDecl decl = new StructDecl(id, fields, methods, this.getLoc(start, this.previous().loc), noMangle);
        if (types.length > 0)
        {
            decl.isTemplate = true;
            decl.templateType = types;
        }
        return decl;
    }

    FuncDecl parseFuncDecl(TypeExpr funcType, Token id)
    {
        bool isVarArg, isExtern, noMangle;
        FuncArgument[] arguments;
        this.consume(TokenKind.LParen, "Expected '(' after the function name.");
        while (!this.check(TokenKind.RParen))
        {
            if (this.match([TokenKind.Variadic]))
            {
                arguments ~= FuncArgument("...", null, null, null, this.previous().loc, true);
                isVarArg = true;
                // Varargs deve ser o último argumento
                if (!this.check(TokenKind.RParen))
                    reportError("Variadic arguments must be the last parameter.", this.peek().loc);
                break;
            }
            TypeExpr type = this.parseType();
            Token argId = this.consume(TokenKind.Identifier, "An identifier is expected for the argument name.");
            Node valueDefault = null;
            if (this.match([TokenKind.Equals]))
                valueDefault = this.parseExpression();
            arguments ~= FuncArgument(argId.value.get!string, type, Type.init, valueDefault,
                argId.loc);
            this.match([TokenKind.Comma]);
        }
        this.consume(TokenKind.RParen, "Expected ')' after the function arguments.");

        if (this.match([TokenKind.NoMangle]))
            noMangle = true;

        Node[] body = [];
        if (this.match([TokenKind.SemiColon]))
            isExtern = true;
        else
            body = parseBody();

        return new FuncDecl(id.value.get!string, arguments, body, funcType, id.loc, isVarArg, isExtern, noMangle);
    }

    TypeDecl parseTypeDecl()
    {
        this.advance();
        Token id = this.consume(TokenKind.Identifier, "An identifier is expected for the type name.");
        this.consume(TokenKind.Equals, "Expected '=' after the type declaration.");
        TypeExpr type = this.parseType();
        if (!registry.typePreExists(id.value.get!string))
            registry.registerPreType(id.value.get!string, type);
        return new TypeDecl(id.value.get!string, type, id.loc);
    }

    VarDecl parseVarDecl(TypeExpr type, Token id, bool isConst = false)
    {
        Node value = null;

        if (!this.check(TokenKind.SemiColon))
        {
            this.consume(TokenKind.Equals, "Expected '=' after the variable declaration.");
            value = this.parseExpression();
        }
        else
            this.advance();

        return new VarDecl(id.value.get!string, type, value, isConst, id.loc);
    }
}
