module frontend.types.builtins;

import frontend.types.type;
import std.stdio;

class BuiltinTypes
{
    static PrimitiveType _Int; // i32
    static PrimitiveType _Long; // i64
    static PrimitiveType _Float; // f32
    static PrimitiveType _Double; // f64
    static PrimitiveType _Bool; // i1
    static PointerType _String; // string
    static PrimitiveType _Char; // char
    static PrimitiveType _Void; // void
    static PrimitiveType _Any; // any

    static PrimitiveType _Null;
    static PrimitiveType _Never;
    static Type[string] aliases;

    static void initialize()
    {
        _Int = new PrimitiveType(BaseType.Int);
        _Long = new PrimitiveType(BaseType.Long);
        _Float = new PrimitiveType(BaseType.Float);
        _Double = new PrimitiveType(BaseType.Double);
        _Bool = new PrimitiveType(BaseType.Bool);
        _String = new PointerType(new PrimitiveType(BaseType.Char));
        _Char = new PrimitiveType(BaseType.Char);
        _Void = new PrimitiveType(BaseType.Void);
        _Null = new PrimitiveType(BaseType.Void);

        registerAliases();
    }

    private static void registerAliases()
    {
        aliases["int"] = _Int;
        aliases["long"] = _Long;
        aliases["float"] = _Float;
        aliases["double"] = _Double;
        aliases["bool"] = _Bool;
        aliases["char"] = _Char;
        aliases["string"] = _String;
        aliases["char*"] = _String; // hack for templates
        aliases["void"] = _Void;
        aliases["null"] = _Null;
        aliases["i1"] = _Bool;
        aliases["i32"] = _Int;
        aliases["i64"] = _Long;
        aliases["f32"] = _Float;
        aliases["f64"] = _Double;
    }

    static bool isPrimitiveTypeName(string name)
    {
        return (name in aliases) !is null;
    }

    static Type getPrimitive(string name)
    {
        if (auto type = name in aliases)
            return *type;
        return null;
    }

    static string[] listPrimitives()
    {
        return aliases.keys;
    }
}
