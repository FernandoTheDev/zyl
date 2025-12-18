module frontend.semantic.type_resolution;

import std.algorithm;
import frontend;
import common.reporter;

class TypeResolver
{
    Context ctx;
    DiagnosticError error;
    TypeRegistry registry;
    TemplateInstantiator instantiator;
    StructDecl[] structs;

    this(Context ctx, DiagnosticError error, TypeRegistry registry, TemplateInstantiator instantiator = null)
    {
        this.ctx = ctx;
        this.error = error;
        this.registry = registry;
        this.instantiator = instantiator;
    }

    Type resolve(TypeExpr typeExpr)
    {
        if (typeExpr is null)
            return null;

        return this.resolveInternal(typeExpr);
    }

private:
    pragma(inline, true)
    void reportError(string message, Loc loc, Suggestion[] suggestions = null)
    {
        error.addError(Diagnostic(message, loc, suggestions));
    }

    Type resolveInternal(TypeExpr typeExpr)
    {
        if (auto named = cast(NamedTypeExpr) typeExpr)
            return resolveNamed(named);

        if (auto arr = cast(ArrayTypeExpr) typeExpr)
            return resolveArray(arr);

        if (auto ptr = cast(PointerTypeExpr) typeExpr)
            return resolvePointer(ptr);

        if (auto fn = cast(FunctionTypeExpr) typeExpr)
            return resolveFuncType(fn);

        if (auto ge = cast(GenericTypeExpr) typeExpr)
            return resolveGenericType(ge);

        reportError("Unknown type in the resolution.", typeExpr.loc);
        return new PrimitiveType(BaseType.Any);
    }

    Type resolveGenericType(GenericTypeExpr ge)
    {
        string[] types = ge.typeArgs.map!(t => t.toStr()).array;
        string t = ge.baseType.toStr() ~ "_" ~ types.join("_");
        
        if (registry.lookupType(t) !is null)
            return registry.lookupType(t);
        
        Type baseType = resolve(ge.baseType);
        StructSymbol templateSym = ctx.lookupStruct(baseType.toStr()); 
        
        if (!templateSym) {
            reportError("Template struct not found.", ge.loc);
            return new PrimitiveType(BaseType.Any);
        }

        if (!instantiator) {
             reportError("Internal compiler error: Template instantiator missing.", ge.loc);
             return new PrimitiveType(BaseType.Any);
        }

        StructSymbol instanceSym = instantiator.instantiateStructFromTypes(templateSym, ge.typeArgs, ge.loc);

        if (instanceSym && instanceSym.type)
        {
            structs ~= instanceSym.declaration;
            return instanceSym.type;
        }

        return new PrimitiveType(BaseType.Any);
    }

    Type resolveFuncType(FunctionTypeExpr fn)
    {
        Type[] types = fn.paramTypes.map!(t => resolve(t)).array;
        return new FunctionType(types, resolve(fn.returnType));
    }

    Type resolveNamed(NamedTypeExpr named)
    {
        string name = named.name;
        if (!registry.typeExists(name))
        {
            writeln(registry.listAllTypes()); // debug
            reportError(format("The type '%s' does not exist.", name), named.loc);
            return new PrimitiveType(BaseType.Any);
        }
        return registry.lookupType(name);
    }

    Type resolveArray(ArrayTypeExpr arr)
    {
        Type elemType = resolve(arr.elementType);

        if (elemType is null)
        {
            reportError("The type of the array element cannot be resolved.", arr.loc);
            return new PrimitiveType(BaseType.Any);
        }

        return new ArrayType(elemType, 1, arr.length);
    }

    Type resolvePointer(PointerTypeExpr ptr)
    {
        Type pointeeType = resolve(ptr.pointeeType);

        if (pointeeType is null)
        {
            reportError("The specified type cannot be resolved.", ptr.loc);
            return new PrimitiveType(BaseType.Any);
        }

        return new PointerType(pointeeType);
    }
}
