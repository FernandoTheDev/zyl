module frontend.semantic.context;

import frontend;
import std.format : format;
import std.stdio : writeln, writefln;
import std.array : replicate;

enum SymbolKind
{
    Variable,
    Function,
    Struct,
}

abstract class Symbol
{
    string name;
    SymbolKind kind;
    Loc loc;
    Type type;
    bool isPublic = true; // por padrão, símbolos são públicos
    bool isExternal = false; // importado de outro módulo

    this(string name, SymbolKind kind, Type type, Loc loc)
    {
        this.name = name;
        this.kind = kind;
        this.type = type;
        this.loc = loc;
    }

    // Clona o símbolo (útil para imports)
    abstract Symbol clone();
}

class VarSymbol : Symbol
{
    bool isConst;
    bool isGlobal;

    this(string name, Type type, bool isConst, bool isGlobal, Loc loc)
    {
        super(name, SymbolKind.Variable, type, loc);
        this.isConst = isConst;
        this.isGlobal = isGlobal;
    }

    override Symbol clone()
    {
        auto cloned = new VarSymbol(name, type, isConst, isGlobal, loc);
        cloned.isPublic = this.isPublic;
        cloned.isExternal = true;
        return cloned;
    }
}

class FunctionSymbol : Symbol
{
    Type[] paramTypes;
    Type returnType;
    FuncDecl declaration;

    this(string name, Type[] paramTypes, Type returnType,
        FuncDecl declaration, Loc loc)
    {
        super(name, SymbolKind.Function, returnType, loc);
        this.paramTypes = paramTypes;
        this.returnType = returnType;
        this.declaration = declaration;
    }

    override Symbol clone()
    {
        auto cloned = new FunctionSymbol(name, paramTypes.dup, returnType, 
                                        declaration, loc);
        cloned.isPublic = this.isPublic;
        cloned.isExternal = true;
        return cloned;
    }
}

class StructSymbol : Symbol
{
    StructDecl declaration;
    StructType structType;

    this(string name, StructType structType, StructDecl declaration, Loc loc)
    {
        super(name, SymbolKind.Struct, structType, loc);
        this.structType = structType;
        this.declaration = declaration;
    }

    override Symbol clone()
    {
        auto cloned = new StructSymbol(name, structType, declaration, loc);
        cloned.isPublic = this.isPublic;
        cloned.isExternal = true;
        return cloned;
    }

    bool hasField(string fieldName)
    {
        return structType.hasField(fieldName);
    }

    Type getFieldType(string fieldName)
    {
        return structType.getFieldType(fieldName);
    }

    bool hasMethod(string methodName)
    {
        return structType.hasMethod(methodName);
    }

    StructMethod* getConstructor()
    {
        return structType.getConstructor();
    }

    StructMethod* getMethod(string methodName)
    {
        return structType.getMethod(methodName);
    }
}

class Scope
{
    Scope parent;
    Symbol[string] symbols;
    Scope[string] namespaces;
    string name;

    this(Scope parent, string name = "")
    {
        this.parent = parent;
        this.name = name;
    }

    bool addToNamespace(string namespaceName, Symbol symbol)
    {
        if (namespaceName !in namespaces)
            namespaces[namespaceName] = new Scope(null, namespaceName);
        
        return namespaces[namespaceName].define(symbol);
    }

    Scope getNamespace(string namespaceName)
    {
        return namespaces.get(namespaceName, null);
    }

    bool define(Symbol symbol)
    {
        if (symbol.name in symbols)
            return false;

        symbols[symbol.name] = symbol;
        return true;
    }

    Symbol lookupLocal(string name)
    {
        return symbols.get(name, null);
    }

    Symbol lookupInNamespace(string namespaceName, string symbolName)
    {
        auto ns = getNamespace(namespaceName);
        if (ns is null)
            return null;
        return ns.lookupLocal(symbolName);
    }

    Symbol lookup(string name)
    {
        // Verifica se é uma referência qualificada (namespace.symbol)
        import std.algorithm : canFind;
        import std.string : indexOf;
        
        auto colonPos = name.indexOf("::");
        if (colonPos != -1)
        {
            string nsName = name[0 .. colonPos];
            string symName = name[colonPos + 2 .. $];
            return lookupInNamespace(nsName, symName);
        }

        // Busca normal
        Symbol sym = lookupLocal(name);
        if (sym !is null)
            return sym;

        if (parent !is null)
            return parent.lookup(name);

        return null;
    }

    bool isDefined(string name)
    {
        return lookup(name) !is null;
    }

    // Retorna todos os símbolos públicos (útil para imports)
    Symbol[] getPublicSymbols()
    {
        Symbol[] result;
        foreach (sym; symbols)
            result ~= sym;
        return result;
    }
}

class Context
{
    Scope currentScope;
    Scope globalScope;
    FunctionSymbol currentFunction;
    StructSymbol currentStruct;
    int loopDepth;

    this()
    {
        this.globalScope = new Scope(null, "global");
        this.currentScope = globalScope;
        this.currentFunction = null;
        this.currentStruct = null;
        this.loopDepth = 0;
    }

    void enterScope(string name = "")
    {
        currentScope = new Scope(currentScope, name);
    }

    void exitScope()
    {
        if (currentScope.parent is null)
            throw new Exception("Tentativa de sair do escopo global");
        currentScope = currentScope.parent;
    }

    void enterFunction(FunctionSymbol func)
    {
        currentFunction = func;
        enterScope(format("func:%s", func.name));
    }

    void exitFunction()
    {
        currentFunction = null;
        exitScope();
    }

    void enterStruct(StructSymbol structSym)
    {
        currentStruct = structSym;
        enterScope(format("struct:%s", structSym.name));
    }

    void exitStruct()
    {
        currentStruct = null;
        exitScope();
    }

    void enterLoop()
    {
        loopDepth++;
        enterScope("loop");
    }

    void exitLoop()
    {
        loopDepth--;
        exitScope();
    }

    bool isInLoop()
    {
        return loopDepth > 0;
    }

    bool isInFunction()
    {
        return currentFunction !is null;
    }

    bool isInStruct()
    {
        return currentStruct !is null;
    }

    bool addSymbol(Symbol symbol)
    {
        return currentScope.define(symbol);
    }

    bool addVariable(string name, Type type, bool isConst, Loc loc)
    {
        auto sym = new VarSymbol(name, type, isConst,
            currentScope == globalScope, loc);
        return addSymbol(sym);
    }

    bool addFunction(FunctionSymbol func)
    {
        return globalScope.define(func);
    }

    bool addStruct(StructSymbol structSym)
    {
        return globalScope.define(structSym);
    }

    // Importa um símbolo de outro contexto
    bool importSymbol(Symbol symbol, string aliasName = "")
    {
        Symbol cloned = symbol.clone();
        if (aliasName != "")
            return globalScope.addToNamespace(aliasName, cloned);
        else
        {
            if (globalScope.lookupLocal(cloned.name) !is null)
                return false; // Já existe    
            return globalScope.define(cloned);
        }
    }

    // Importa múltiplos símbolos
    void importSymbols(Symbol[] symbols, string aliasName = "")
    {
        foreach (sym; symbols)
            importSymbol(sym, aliasName);
    }

    Symbol lookup(string name)
    {
        return currentScope.lookup(name);
    }

    Symbol lookupLocal(string name)
    {
        return currentScope.lookupLocal(name);
    }

    VarSymbol lookupVariable(string name)
    {
        Symbol sym = lookup(name);
        return cast(VarSymbol) sym;
    }

    FunctionSymbol lookupFunction(string name)
    {
        Symbol sym = globalScope.lookup(name);
        return cast(FunctionSymbol) sym;
    }

    StructSymbol lookupStruct(string name)
    {
        Symbol sym = globalScope.lookup(name);
        return cast(StructSymbol) sym;
    }

    bool canAssign(string varName)
    {
        VarSymbol var = lookupVariable(varName);
        if (var is null)
            return false;
        return !var.isConst;
    }

    bool isDefined(string name)
    {
        return currentScope.isDefined(name);
    }

    // Retorna todos os símbolos públicos do escopo global
    Symbol[] getPublicSymbols()
    {
        return globalScope.getPublicSymbols();
    }

    void dump()
    {
        writeln("=== CONTEXT DUMP ===");
        dumpScope(globalScope, 0);
    }

    void dumpScope(Scope scope_, int indent)
    {
        string prefix = " ".replicate(indent * 2);
        writefln("%sScope: %s", prefix, scope_.name);
        Type type;

        foreach (name, sym; scope_.symbols)
        {
            if (sym.kind == SymbolKind.Function)
                type = (cast(FunctionSymbol) sym).returnType;
            else if (sym.kind == SymbolKind.Struct)
                type = (cast(StructSymbol) sym).structType;
            else
                type = sym.type;
            
            string extMarker = sym.isExternal ? " [external]" : "";
            string pubMarker = sym.isPublic ? " [public]" : " [private]";
            
            writefln("%s  - %s: %s (%s)%s%s",
                prefix, name, sym.kind,
                type !is null ? type.toStr() : "no-type",
                extMarker, pubMarker);
            
            if (sym.kind == SymbolKind.Struct)
            {
                auto structSym = cast(StructSymbol) sym;
                if (structSym.structType.fields.length > 0)
                {
                    writefln("%s    Fields:", prefix);
                    foreach (field; structSym.structType.fields)
                    {
                        writefln("%s      - %s: %s", prefix, field.name, 
                                field.resolvedType !is null ? field.resolvedType.toStr() : "unresolved");
                    }
                }
                if (structSym.structType.methods.length > 0)
                {
                    writefln("%s    Methods:", prefix);
                    foreach (method; structSym.structType.methods)
                    {
                        string methodType = method.isConstructor ? "constructor" : "method";
                        writefln("%s      - %s (%s)", prefix, method.funcDecl.name, methodType);
                    }
                }
            }
        }

        // Dump namespaces
        if (scope_.namespaces.length > 0)
        {
            writefln("%sNamespaces:", prefix);
            foreach (nsName, ns; scope_.namespaces)
            {
                writefln("%s  Namespace: %s", prefix, nsName);
                dumpScope(ns, indent + 2);
            }
        }
    }
}
