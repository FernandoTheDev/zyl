module frontend.types.type;

import frontend;

enum BaseType : string
{
    String = "string",
    Char = "char",
    Int = "int",
    Long = "long",
    Float = "float",
    Double = "double",
    Bool = "bool",
    Void = "void",
    Any = "any",
}

const int[string] TYPE_HIERARCHY = [
    BaseType.Bool: 1,
    BaseType.Char: 1,
    BaseType.Int: 2,
    BaseType.Long: 3,
    BaseType.Float: 4,
    BaseType.Double: 5,
];

abstract class Type
{
    abstract bool isCompatibleWith(Type other, bool strict = true);
    abstract string toStr();
    abstract Type clone();

    bool isNumeric()
    {
        return false;
    }

    bool isArray()
    {
        return false;
    }

    bool isStruct()
    {
        return false;
    }

    bool isEnum()
    {
        return false;
    }

    bool isPrimitive()
    {
        return false;
    }

    bool isVoid()
    {
        return false;
    }

    bool isQualified()
    {
        return false;
    }

    bool isUnion()
    {
        return false;
    }

    bool isPointer()
    {
        return false;
    }

    Type getPromotedType(Type other)
    {
        if (auto prim1 = cast(PrimitiveType) this)
            if (auto prim2 = cast(PrimitiveType) other)
                return PrimitiveType.promote(prim1, prim2);
        return this;
    }
}

class PrimitiveType : Type
{
    BaseType baseType;

    private static immutable string[][string] STRICT_COMPAT;
    private static immutable string[][string] LIBERAL_COMPAT;

    shared static this()
    {
        STRICT_COMPAT = [
            BaseType.Int: [
                BaseType.Long, BaseType.Char
            ],
            BaseType.Long: [BaseType.Double],
            BaseType.Float: [BaseType.Double],
            BaseType.Double: [],
            BaseType.Bool: [
                BaseType.Int, BaseType.Long, BaseType.Float, BaseType.Double
            ],
            BaseType.String: [
                BaseType.Int, BaseType.Long, BaseType.Float, BaseType.Double,
                BaseType.Bool, BaseType.Char
            ],
            BaseType.Char: [BaseType.Int]
        ];

        LIBERAL_COMPAT = [
            BaseType.Int: [
                BaseType.Long, BaseType.Float, BaseType.Double,
                BaseType.Bool, BaseType.Char
            ],
            BaseType.Long: [
                BaseType.Int, BaseType.Float, BaseType.Double,
                BaseType.Bool, BaseType.Char
            ],
            BaseType.Float: [
                BaseType.Int, BaseType.Long, BaseType.Double,
                BaseType.Bool
            ],
            BaseType.Double: [
                BaseType.Int, BaseType.Long, BaseType.Float,
                BaseType.Bool
            ],
            BaseType.Bool: [
                BaseType.Int, BaseType.Long, BaseType.Float,
                BaseType.Double
            ],
            BaseType.String: [
                BaseType.Int, BaseType.Long, BaseType.Float,
                BaseType.Double, BaseType.Bool
            ],
            BaseType.Char: [BaseType.Int]
        ];
    }

    this(BaseType baseType)
    {
        this.baseType = baseType;
    }

    override bool isPrimitive()
    {
        return true;
    }

    override bool isNumeric()
    {
        return baseType == BaseType.Int || baseType == BaseType.Long
            || baseType == BaseType.Float || baseType == BaseType.Double || baseType == BaseType.Char;
    }

    override bool isCompatibleWith(Type other, bool strict = true)
    {
        if (baseType == BaseType.Any)
            return true;

        if (auto otherPrim = cast(PrimitiveType) other)
        {
            if (otherPrim.baseType == BaseType.Any)
                return true;

            if (baseType == otherPrim.baseType)
                return true;

            string thisStr = baseType;
            string otherStr = otherPrim.baseType;

            if (thisStr in STRICT_COMPAT && STRICT_COMPAT[thisStr].canFind(otherStr))
                return true;

            if (!strict)
                if (thisStr in LIBERAL_COMPAT && LIBERAL_COMPAT[thisStr].canFind(otherStr))
                    return true;
        }

        if (auto fn = cast(FunctionType) other)
            return isCompatibleWith(fn.returnType);

        return false;
    }

    override bool isVoid()
    {
        return baseType == BaseType.Void;
    }

    override string toStr()
    {
        return cast(string) baseType;
    }

    override Type clone()
    {
        return new PrimitiveType(baseType);
    }

    static PrimitiveType promote(PrimitiveType left, PrimitiveType right)
    {
        int leftLevel = TYPE_HIERARCHY.get(cast(string) left.baseType, 0);
        int rightLevel = TYPE_HIERARCHY.get(cast(string) right.baseType, 0);
        return (leftLevel >= rightLevel) ? left : right;
    }
}

class VoidType : Type
{
    private static VoidType _instance;

    // Singleton
    static VoidType instance()
    {
        if (_instance is null)
            _instance = new VoidType();
        return _instance;
    }

    this()
    {
    }

    override bool isVoid()
    {
        return true;
    }

    override bool isCompatibleWith(Type other, bool strict = true)
    {
        if (auto vd = cast(VoidType) other)
            return true;
        if (PrimitiveType prim = cast(PrimitiveType) other)
            return prim.baseType == BaseType.Void;
        return false;
    }

    override string toStr()
    {
        return "void";
    }

    override Type clone()
    {
        return instance();
    }
}

class ArrayType : Type
{
    Type elementType;
    int dimensions;
    long length = 0;

    this(Type elementType, int dimensions = 1, long length = 0)
    {
        this.elementType = elementType;
        this.dimensions = dimensions;
        this.length = length;
    }

    override bool isArray()
    {
        return true;
    }

    override bool isCompatibleWith(Type other, bool strict = true)
    {
        if (auto otherArray = cast(ArrayType) other)
        {
            // Arrays devem ter o mesmo número de dimensões
            if (dimensions != otherArray.dimensions)
                return false;

            // o meu array left deve ter o mesmo tamanho ou ser maior que o right (other)
            if (length < otherArray.length)
                return false;

            // O tipo dos elementos deve ser compatível
            return elementType.isCompatibleWith(otherArray.elementType, strict);
        }

        return false;
    }

    override string toStr()
    {
        string result = elementType.toStr();
        for (int i = 0; i < dimensions; i++)
            result ~= "[" ~ to!string(length) ~ "]";
        return result;
    }

    override Type clone()
    {
        return new ArrayType(elementType.clone(), dimensions, length);
    }

    // Retorna o tipo base (sem as dimensões de array)
    Type getBaseType()
    {
        return elementType;
    }
}

class UnionType : Type
{
    Type[] types;

    this(Type[] types)
    {
        this.types = types;
    }

    override bool isCompatibleWith(Type other, bool strict = true)
    {
        // se other for um UnionType, verifica se todos os tipos de other
        // são compatíveis com pelo menos um tipo deste union
        if (auto otherUnion = cast(UnionType) other)
        {
            foreach (otherType; otherUnion.types)
                foreach (thisType; types)
                    if (thisType.isCompatibleWith(otherType, strict))
                        return true;
            return false;
        }

        // Se other for um tipo simples, verifica se é compatível
        // com pelo menos um dos tipos do union
        foreach (type; types)
            if (type.isCompatibleWith(other, strict))
                return true;

        return false;
    }

    override string toStr()
    {
        return types.map!(t => t.toStr()).join(" | ");
    }

    override Type clone()
    {
        return new UnionType(types.map!(t => t.clone()).array);
    }

    override bool isNumeric()
    {
        // Um union é numérico se todos os seus tipos forem numéricos
        foreach (type; types)
            if (!type.isNumeric())
                return false;
        return types.length > 0;
    }

    override bool isUnion()
    {
        return true;
    }

    // Verifica se o union contém um tipo específico
    bool containsType(Type type)
    {
        foreach (t; types)
            if (t.isCompatibleWith(type, true))
                return true;
        return false;
    }

    // Adiciona um novo tipo ao union (evita duplicatas)
    void addType(Type type)
    {
        if (!containsType(type))
            types ~= type;
    }
}

class PointerType : Type
{
    Type pointeeType;

    this(Type pointeeType)
    {
        this.pointeeType = pointeeType;
    }

    override bool isCompatibleWith(Type other, bool strict = true)
    {
        if (auto otherPtr = cast(PointerType) other) {
            if (toStr() == "void*" || other.toStr() == "void*")
                return true;
            return pointeeType.isCompatibleWith(otherPtr.pointeeType, strict);
        }
        return false;
    }

    override bool isPointer()
    {
        return true;
    }

    override string toStr()
    {
        return format("%s*", pointeeType.toStr());
    }

    override Type clone()
    {
        return new PointerType(pointeeType.clone());
    }
}

/// Tipo função: (inteiro, texto): logico
class FunctionType : Type
{
    Type[] paramTypes;
    Type returnType;

    this(Type[] paramTypes, Type returnType)
    {
        this.paramTypes = paramTypes;
        this.returnType = returnType;
    }

    override bool isCompatibleWith(Type other, bool strict = true)
    {
        // Compatibilidade com outra função
        if (auto otherFunc = cast(FunctionType) other)
        {
            // Número de parâmetros deve ser igual
            if (paramTypes.length != otherFunc.paramTypes.length)
                return false;

            // Tipo de retorno deve ser compatível
            if (!returnType.isCompatibleWith(otherFunc.returnType, strict))
                return false;

            // Todos os parâmetros devem ser compatíveis
            foreach (i, thisParamType; paramTypes)
            {
                Type otherParamType = otherFunc.paramTypes[i];
                if (!thisParamType.isCompatibleWith(otherParamType, strict))
                    return false;
            }

            return true;
        }

        // Compatibilidade com union type
        if (auto unionType = cast(UnionType) other)
            return unionType.isCompatibleWith(returnType, strict);

        return false;
    }

    override string toStr()
    {
        string params = paramTypes.map!(t => t is null ? "..." : t.toStr()).join(", ");
        return "(" ~ params ~ ") -> " ~ returnType.toStr();
    }

    override Type clone()
    {
        Type[] clonedParams = paramTypes.map!(t => t.clone()).array;
        return new FunctionType(clonedParams, returnType.clone());
    }
}

class StructType : Type
{
    string name;
    StructField[] fields;
    StructMethod[] methods;
    
    // Mapeia nome do campo para seu índice
    private int[string] fieldIndexMap;

    this(string name, StructField[] fields = [], StructMethod[] methods = [])
    {
        this.name = name;
        this.fields = fields;
        this.methods = methods;
        
        // Constrói o mapa de campos
        foreach (i, field; fields)
            fieldIndexMap[field.name] = cast(int) i;
    }

    override bool isCompatibleWith(Type other, bool strict = true)
    {
        // Compatibilidade nominal: structs devem ter o mesmo nome
        // compativel com null
        if (other.toStr() == "void*")
            return true;
        if (auto otherStruct = cast(StructType) other)
            return name == otherStruct.name;
        return false;
    }

    override string toStr()
    {
        return name;
    }

    override Type clone()
    {
        return new StructType(name, fields.dup, methods.dup);
    }

    override bool isStruct()
    {
        return true;
    }

    // Busca um campo pelo nome
    StructField* getField(string fieldName)
    {
        if (auto idx = fieldName in fieldIndexMap)
            return &fields[*idx];
        return null;
    }

    // Busca um método pelo nome
    StructMethod* getMethod(string methodName)
    {
        foreach (ref method; methods)
            if (method.funcDecl.name == methodName)
                return &method;
        return null;
    }

    // Busca construtor
    StructMethod* getConstructor()
    {
        foreach (ref method; methods)
            if (method.isConstructor)
                return &method;
        return null;
    }

    // Retorna o tipo de um campo
    Type getFieldType(string fieldName)
    {
        if (auto field = getField(fieldName))
            return field.resolvedType;
        return null;
    }

    // Verifica se tem um campo específico
    bool hasField(string fieldName)
    {
        return (fieldName in fieldIndexMap) !is null;
    }

    // Verifica se tem um método específico
    bool hasMethod(string methodName)
    {
        return getMethod(methodName) !is null;
    }

    // Retorna número de campos
    size_t fieldCount()
    {
        return fields.length;
    }

    void rebuildFieldIndexMap()
    {
        fieldIndexMap.clear();
        foreach (i, field; fields)
            fieldIndexMap[field.name] = cast(int) i;
    }
}
