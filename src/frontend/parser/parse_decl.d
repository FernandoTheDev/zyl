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

        default:
            reportError("Unrecognized statement.", this.peek().loc);
            return null;
        }
    }

    StructDecl parseStructDecl()
    {
        // struct User { string name; int age = 17; User next = null; }
        Loc start = advance().loc;
        string id = this.consume(TokenKind.Identifier, "Expected an identifier to struct name.").value.get!string;
        StructField[] fields;
        StructMethod[] methods;
        // precisa criar um tipo do usuario temporariamente pra conseguir identificar isso como uma struct
        // o typeresolver corrigirá isso no futuro
        if (!registry.typeExists(id))
            registry.registerType(id, new StructType(id, fields, methods)); // registra uma base temporariamente
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
                methods ~= StructMethod(func, func.name == "this", func.loc);
                continue;
            }

            reportError("You can't use that inside the struct.", node.loc);
        }

        this.consume(TokenKind.RBrace, "Expected '}' after struct body.");
        return new StructDecl(id, fields, methods, this.getLoc(start, this.previous().loc));
    }

    FuncDecl parseFuncDecl(TypeExpr funcType, Token id)
    {
        bool isVarArg;
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

        Node[] body;
        if (this.match([TokenKind.SemiColon]))
            body = null;
        else
            body = parseBody();
        return new FuncDecl(id.value.get!string, arguments, body, funcType, id.loc, isVarArg);
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
