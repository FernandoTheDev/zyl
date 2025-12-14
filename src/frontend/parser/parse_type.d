module frontend.parser.parse_type;
import frontend;

mixin template ParseType()
{
    TypeExpr parseType()
    {
        Loc start = this.peek().loc;
        TypeExpr type = this.parsePrimaryType();

        if (this.check(TokenKind.LBracket))
            return this.parseArrayType(type);

        if (this.check(TokenKind.Star))
            return this.parsePointerType(type);

        return type;
    }

    TypeExpr parsePrimaryType()
    {
        Token token = this.peek();

        switch (token.kind)
        {
        case TokenKind.Identifier:
            Token name = this.advance();
            return new NamedTypeExpr(name.value.get!string, name.loc);

        case TokenKind.LParen:
            return this.parseFunctionType();

        default:
            reportError("Expected type, found: " ~ to!string(token.value),
                token.loc);
            throw new Exception("Invalid type");
        }
    }

    // // int[]
    TypeExpr parseArrayType(TypeExpr elementType)
    {
        Loc start = this.advance().loc; // consome '['
        Token len = this.consume(TokenKind.I32, "Expected number of elements the array will have.");
        this.consume(TokenKind.RBracket, "Expected ']' in array type");

        TypeExpr type = new ArrayTypeExpr(elementType,
            this.getLoc(start, elementType.loc), to!long(len.value.get!string));

        if (this.check(TokenKind.LBracket))
            return this.parseArrayType(type);

        if (this.check(TokenKind.Star))
            return this.parsePointerType(type);

        return type;
    }

    // int*
    TypeExpr parsePointerType(TypeExpr pointeeType)
    {
        Loc start = this.advance().loc; // consome '*'
        TypeExpr type = new PointerTypeExpr(pointeeType,
            this.getLoc(start, pointeeType.loc));

        if (this.check(TokenKind.LBracket))
            return this.parseArrayType(type);

        if (this.check(TokenKind.Star))
            return this.parsePointerType(type);

        return type;
    }

    FunctionTypeExpr parseFunctionType()
    {
        Loc start = this.advance().loc; // consome '('

        TypeExpr[] paramTypes;
        if (!this.check(TokenKind.RParen))
        {
            do
                paramTypes ~= this.parseType();
            while (this.match([TokenKind.Comma]));
        }

        this.consume(TokenKind.RParen, "Expected ')' in function type.");

        TypeExpr returnType = null;
        if (this.match([TokenKind.Colon]))
            returnType = this.parseType();

        Loc loc = returnType ? this.getLoc(start, returnType.loc) : this.getLoc(start, this.previous()
                .loc);

        return new FunctionTypeExpr(paramTypes, returnType, loc);
    }
}
