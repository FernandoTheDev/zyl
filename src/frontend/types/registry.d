module frontend.types.registry;

import frontend;
import std.stdio;

class TypeRegistry
{
    private static TypeRegistry _instance;
    private Type[string] userTypes;
    private TypeExpr[string] preUserTypes;
    private Type[string] compositeCache;
    private bool[string] inProgress;

    this()
    {
        BuiltinTypes.initialize();
    }

    static TypeRegistry instance()
    {
        if (_instance is null)
            _instance = new TypeRegistry();
        return _instance;
    }

    bool registerType(string name, Type type)
    {
        if (name in userTypes)
        {
            stderr.writeln("Error: type '", name, "' has already been defined");
            return false;
        }

        if (BuiltinTypes.isPrimitiveTypeName(name))
        {
            stderr.writeln("Error: '", name, "' is a primitive type and cannot be redefined.");
            return false;
        }

        userTypes[name] = type;
        return true;
    }

    bool registerPreType(string name, TypeExpr type)
    {
        if (name in preUserTypes)
        {
            stderr.writeln("Error: pretype '", name, "' has already been defined");
            return false;
        }

        if (BuiltinTypes.isPrimitiveTypeName(name))
        {
            stderr.writeln("Error: '", name, "' is a primitive type and cannot be redefined.");
            return false;
        }

        preUserTypes[name] = type;
        return true;
    }

    bool updateType(string name, Type type)
    {
        userTypes[name] = type;
        return true;
    }

    TypeExpr lookupPreType(string name)
    {
        if (auto userType = name in preUserTypes)
            return *userType;

        return null;
    }

    Type lookupType(string name)
    {
        if (auto prim = BuiltinTypes.getPrimitive(name))
            return prim;

        if (auto userType = name in userTypes)
            return *userType;

        return null;
    }

    bool typePreExists(string name)
    {
        return lookupPreType(name) !is null;
    }

    bool typeExists(string name)
    {
        return lookupType(name) !is null;
    }

    Type getArrayType(Type elementType)
    {
        string key = elementType.toStr() ~ "[]";

        if (auto cached = key in compositeCache)
            return *cached;

        auto arrayType = new ArrayType(elementType);
        compositeCache[key] = arrayType;
        return arrayType;
    }

    bool beginTypeDefinition(string name)
    {
        if (name in inProgress)
        {
            stderr.writeln("Error: circular definition detected for type '", name, "'");
            return false;
        }

        inProgress[name] = true;
        return true;
    }

    void endTypeDefinition(string name)
    {
        inProgress.remove(name);
    }

    bool unregisterType(string name)
    {
        if (BuiltinTypes.isPrimitiveTypeName(name))
        {
            stderr.writeln("Error: cannot remove primitive type '", name, "'");
            return false;
        }

        return userTypes.remove(name);
    }

    string[] listAllTypes()
    {
        string[] types;
        types ~= BuiltinTypes.listPrimitives();
        types ~= userTypes.keys;
        return types.sort.array;
    }

    void dump()
    {
        writeln("\n=== Type Registry Dump ===");
        writeln("Primitive Types: ", BuiltinTypes.aliases.length);
        foreach (name, type; BuiltinTypes.aliases)
            writeln("  - ", name, " -> ", type.toStr());

        writeln("\nUser Types: ", userTypes.length);
        foreach (name, type; userTypes)
            writeln("  - ", name, " : ", type.toStr());

        writeln("\nCompound Cache: ", compositeCache.length);
        foreach (key, type; compositeCache)
            writeln("  - ", key, " : ", type.toStr());

        writeln("========================\n");
    }

    void reset()
    {
        userTypes.clear();
        compositeCache.clear();
        inProgress.clear();
        BuiltinTypes.initialize();
    }
}
