module frontend.types.type_expr;

import frontend;

/// Classe base para expressões de tipo no AST
abstract class TypeExpr : Node
{
    Loc loc;

    abstract string toStr();
    abstract TypeExpr clone();
}

/// Tipo nomeado simples: inteiro, texto, MinhaClasse, etc.
class NamedTypeExpr : TypeExpr
{
    string name;

    this(string name, Loc loc)
    {
        this.name = name;
        this.loc = loc;
    }

    override string toStr()
    {
        return name;
    }

    override TypeExpr clone()
    {
        return new NamedTypeExpr(name, loc);
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
    }
}

/// Tipo array: inteiro[], texto[][], etc.
class ArrayTypeExpr : TypeExpr
{
    TypeExpr elementType;
    long length = 0;

    this(TypeExpr elementType, Loc loc, long length = 0)
    {
        this.elementType = elementType;
        this.loc = loc;
        this.length = length;
    }

    override string toStr()
    {
        return elementType.toStr() ~ "[" ~ to!string(length) ~ "]";
    }

    override TypeExpr clone()
    {
        return new ArrayTypeExpr(elementType.clone(), loc);
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
    }
}

/// Tipo qualificado: modulo.SubModulo.Tipo
class QualifiedTypeExpr : TypeExpr
{
    string[] parts; // ["modulo", "SubModulo", "Tipo"]

    this(string[] parts, Loc loc)
    {
        this.parts = parts;
        this.loc = loc;
    }

    override string toStr()
    {
        import std.array : join;

        return parts.join(".");
    }

    override TypeExpr clone()
    {
        return new QualifiedTypeExpr(parts.dup, loc);
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
    }
}

/// Tipo genérico: Lista<inteiro>, Mapa<texto, inteiro>
class GenericTypeExpr : TypeExpr
{
    TypeExpr baseType;
    TypeExpr[] typeArgs;

    this(TypeExpr baseType, TypeExpr[] typeArgs, Loc loc)
    {
        this.baseType = baseType;
        this.typeArgs = typeArgs;
        this.loc = loc;
    }

    override string toStr()
    {
        import std.algorithm : map;
        import std.array : join;
        import std.conv : to;

        string args = typeArgs.map!(t => t.toStr()).join(", ");
        return baseType.toStr() ~ "<" ~ args ~ ">";
    }

    override TypeExpr clone()
    {
        import std.algorithm : map;
        import std.array : array;

        return new GenericTypeExpr(
            baseType.clone(),
            typeArgs.map!(t => t.clone()).array,
            loc
        );
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
    }
}

/// Tipo função: (inteiro, texto): logico
class FunctionTypeExpr : TypeExpr
{
    TypeExpr[] paramTypes;
    TypeExpr returnType;

    this(TypeExpr[] paramTypes, TypeExpr returnType, Loc loc)
    {
        this.paramTypes = paramTypes;
        this.returnType = returnType;
        this.loc = loc;
    }

    override string toStr()
    {
        import std.algorithm : map;
        import std.array : join;

        string params = paramTypes.map!(t => t.toStr()).join(", ");
        return "(" ~ params ~ ") -> " ~ returnType.toStr();
    }

    override TypeExpr clone()
    {
        import std.algorithm : map;
        import std.array : array;

        return new FunctionTypeExpr(
            paramTypes.map!(t => t.clone()).array,
            returnType.clone(),
            loc
        );
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        import std.stdio : write, writeln;
        import std.array : replicate;

        string prefix = "  ".replicate(cast(size_t) ident);
        string branch = isLast ? "└── " : "├── ";

        writeln(prefix, branch, "FunctionTypeExpr: ");
        writeln(prefix, branch, toStr());
    }
}

class PointerTypeExpr : TypeExpr
{
    TypeExpr pointeeType;

    this(TypeExpr pointeeType, Loc loc)
    {
        this.pointeeType = pointeeType;
        this.loc = loc;
    }

    override string toStr()
    {
        return pointeeType.toStr() ~ "*";
    }

    override TypeExpr clone()
    {
        return new PointerTypeExpr(pointeeType.clone(), loc);
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        import std.stdio : write, writeln;
        import std.array : replicate;

        string prefix = "  ".replicate(cast(size_t) ident);
        string branch = isLast ? "└── " : "├── ";

        writeln(prefix, branch, "PointerTypeExpr");
        writeln(prefix, branch, toStr());
    }
}

class StructTypeExpr : TypeExpr
{
    string structName;

    this(string structName, Loc loc)
    {
        this.structName = structName;
        this.loc = loc;
    }

    override string toStr()
    {
        return structName;
    }

    override TypeExpr clone()
    {
        return new StructTypeExpr(structName, loc);
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        import std.stdio : write, writeln;
        import std.array : replicate;

        string prefix = "  ".replicate(cast(size_t) ident);
        string branch = isLast ? "└── " : "├── ";

        writeln(prefix, branch, "StructTypeExpr: ", structName);
    }
}

class EnumTypeExpr : TypeExpr
{
    string enumName;

    this(string enumName, Loc loc)
    {
        this.enumName = enumName;
        this.loc = loc;
    }

    override string toStr()
    {
        return enumName; // Or "enum " ~ enumName
    }

    override TypeExpr clone()
    {
        return new EnumTypeExpr(enumName, loc);
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        import std.stdio : write, writeln;
        import std.array : replicate;

        string prefix = "  ".replicate(cast(size_t) ident);
        string branch = isLast ? "└── " : "├── ";

        writeln(prefix, branch, "EnumTypeExpr: ", enumName);
    }
}

class UnionTypeExpr : TypeExpr
{
    string unionName;

    this(string unionName, Loc loc)
    {
        this.unionName = unionName;
        this.loc = loc;
    }

    override string toStr()
    {
        return unionName; // Or "union " ~ unionName
    }

    override TypeExpr clone()
    {
        return new UnionTypeExpr(unionName, loc);
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        import std.stdio : write, writeln;
        import std.array : replicate;

        string prefix = "  ".replicate(cast(size_t) ident);
        string branch = isLast ? "└── " : "├── ";

        writeln(prefix, branch, "UnionTypeExpr: ", unionName);
    }
}
