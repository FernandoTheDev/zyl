module frontend.semantic.type_resolution;

import std.algorithm;
import frontend;
import common.reporter;

class TypeResolver
{
    Context ctx;
    DiagnosticError error;
    TypeRegistry registry;

    this(Context ctx, DiagnosticError error, TypeRegistry registry)
    {
        this.ctx = ctx;
        this.error = error;
        this.registry = registry;
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

        if (auto uniont = cast(UnionTypeExpr) typeExpr)
            return resolveUnion(uniont);

        if (auto fn = cast(FunctionTypeExpr) typeExpr)
            return resolveFuncType(fn);

        reportError("Unknown type in the resolution.", typeExpr.loc);
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

    Type resolveUnion(UnionTypeExpr uniont)
    {
        Type[] types = uniont.types.map!(t => resolve(t)).array;
        return new UnionType(types);
    }
}
