module frontend.semantic.semantic2;

import frontend;
import common.reporter;

class Semantic2
{
    Context ctx;
    TypeResolver resolver;
    DiagnosticError error;
    TypeRegistry registry;

    this(Context ctx, DiagnosticError error, TypeRegistry registry)
    {
        this.ctx = ctx;
        this.error = error;
        this.resolver = new TypeResolver(ctx, error, registry);
        this.registry = registry;
    }

    pragma(inline, true)
    void reportError(string message, Loc loc, Suggestion[] suggestions = null)
    {
        error.addError(Diagnostic(message, loc, suggestions));
    }

    void analyze(Program program)
    {
        foreach (node; program.body)
            resolveDeclaration(node);
    }

    void resolveDeclaration(Node node)
    {
        if (auto varDecl = cast(VarDecl) node)
            resolveVarDecl(varDecl);
        else if (auto funcDecl = cast(FuncDecl) node)
            resolveFunctionDecl(funcDecl);
        else if (auto type = cast(TypeDecl) node)
            resolveTypeDecl(type);
        else if (auto stmt = cast(VersionStmt) node)
            resolveVersionStmt(stmt);
        else if (auto decl = cast(StructDecl) node)
            resolveStructDecl(decl);
    }

    void resolveStructDecl(StructDecl decl)
    {
        StructSymbol structSym = ctx.lookupStruct(decl.name);
        if (structSym is null)
        {
            reportError(format("Struct '%s' not found in the context.", decl.name), decl.loc);
            return;
        }

        foreach (ref field; decl.fields)
        {
            field.resolvedType = resolver.resolve(field.type);
            if (field.resolvedType is null)
            {
                reportError(format("Could not resolve type '%s' for field '%s'.", field.type.toStr(), field.name), 
                    field.loc);
                field.resolvedType = new PrimitiveType(BaseType.Any);
            }
        }

        structSym.structType.fields = decl.fields;
        foreach (ref method; decl.methods)
        {
            foreach (ref param; method.funcDecl.args)
            {
                param.resolvedType = resolver.resolve(param.type);
                if (param.resolvedType is null)
                {
                    reportError(format("Could not resolve type '%s' for parameter '%s' in method '%s'.", 
                        param.type.toStr(), param.name, method.funcDecl.name), param.loc);
                    param.resolvedType = new PrimitiveType(BaseType.Any);
                }
            }

            if (method.isConstructor)
                method.funcDecl.resolvedType = structSym.structType;
            else
            {
                // Métodos normais têm tipo de retorno explícito
                method.funcDecl.resolvedType = resolver.resolve(method.funcDecl.type);
                // Valida que o tipo foi resolvido
                if (method.funcDecl.resolvedType is null)
                {
                    reportError(format("Could not resolve return type '%s' for method '%s'.", 
                        method.funcDecl.type.toStr(), method.funcDecl.name), method.funcDecl.loc);
                    method.funcDecl.resolvedType = new PrimitiveType(BaseType.Void);
                }
            }
        }

        structSym.structType.methods = decl.methods;
        // 6. Reconstrói o mapa de índices de campos (importante após atualizar fields)
        structSym.structType.rebuildFieldIndexMap();
        decl.resolvedType = structSym.structType;

        // apenas atualiza o tipo
        StructType existingType = cast(StructType) registry.lookupType(decl.name);
        existingType.fields = structSym.structType.fields;
        existingType.methods = structSym.structType.methods;
        existingType.rebuildFieldIndexMap();
    }

    void resolveVersionStmt(VersionStmt stmt)
    {
        if (stmt.thenBranch !is null)
            foreach (node; stmt.thenBranch.statements)
                resolveDeclaration(node);

        if (stmt.elseBranch !is null)
            resolveDeclaration(stmt.elseBranch);
    }

    void resolveTypeDecl(TypeDecl decl)
    {
        string typename = decl.value.get!string;
        if (resolver.registry.typeExists(typename))
        {
            error.addError(Diagnostic(
                    format("The '%s' type already exists.", typename),
                    decl.loc
            ));
            return;
        }
        decl.resolvedType = resolver.resolve(decl.type);
        resolver.registry.registerType(typename, decl.resolvedType);
    }

    void resolveVarDecl(VarDecl decl)
    {
        // Se tem anotação de tipo, resolve
        if (decl.type !is null)
            decl.resolvedType = resolver.resolve(decl.type);
        // Se não tem anotação mas tem inicializador, deixa null para inferir depois
        else if (decl.value.get!Node !is null)
            decl.resolvedType = null; // será inferido no Semantic3
        // Se não tem nem tipo nem inicializador, erro
        else
        {
            error.addError(Diagnostic(
                    format("The variable '%s' needs a type or initializer.", decl.id),
                    decl.loc
            ));
            decl.resolvedType = new PrimitiveType(BaseType.Any);
            return;
        }

        VarSymbol sym = ctx.lookupVariable(decl.id);
        if (sym !is null && decl.resolvedType !is null)
            sym.type = decl.resolvedType;
    }

    void resolveFunctionDecl(FuncDecl decl)
    {
        FunctionSymbol funcSym = ctx.lookupFunction(decl.name);
        if (funcSym is null)
        {
            reportError(format("Function '%s' not found in the context.", decl.name), decl.loc);
            return;
        }

        Type[] paramTypes;
        foreach (i, ref param; decl.args)
        {
            Type paramType = null;
            paramType = resolver.resolve(param.type);
            paramTypes ~= paramType;
            param.resolvedType = paramType;
        }

        decl.resolvedType = resolver.resolve(decl.type);
        funcSym.paramTypes = paramTypes;
        funcSym.returnType = decl.resolvedType;
    }
}
