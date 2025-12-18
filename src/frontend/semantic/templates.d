module frontend.semantic.templates;

import frontend;
import common.reporter;
import frontend.semantic.type_checker;

class TemplateInstantiator
{
    Context ctx;
    DiagnosticError error;
    TypeRegistry registry;
    TypeChecker checker; // Referência para chamar analise semântica
    StructDecl[] pendingStructs;

    this(Context ctx, DiagnosticError error, TypeRegistry registry, TypeChecker checker)
    {
        this.ctx = ctx;
        this.error = error;
        this.registry = registry;
        this.checker = checker;
    }

    StructSymbol instantiateStructFromTypes(StructSymbol templateSym, TypeExpr[] concreteTypes, Loc loc)
    {
        StructDecl templateDecl = cast(StructDecl) templateSym.declaration;
        if (!templateDecl) return null;

        if (concreteTypes.length != templateDecl.templateType.length)
        {
            error.addError(Diagnostic(
                format("Struct template '%s' expects %d types, got %d.", 
                templateDecl.name, templateDecl.templateType.length, concreteTypes.length), 
                loc));
            return null;
        }

        TypeResolver resolver = new TypeResolver(ctx, error, registry, this);
        string[] genericNames;
        string mangleSuffix = "";
        TypeExpr[] validatedConcreteExprs; // Tipos para substituição na AST

        foreach (i, tExpr; concreteTypes)
        {
            Type t = resolver.resolve(tExpr);
            if (!t) return null;
            
            validatedConcreteExprs ~= tExpr;
            mangleSuffix ~= "_" ~ t.toStr();

            if (auto named = cast(NamedTypeExpr) templateDecl.templateType[i])
                genericNames ~= named.name;
        }

        string instanceName = templateDecl.name ~ mangleSuffix;
        if (Symbol s = ctx.lookup(instanceName))
            if (auto st = cast(StructSymbol) s) return st;
            
        StructDecl newStruct = cast(StructDecl) templateDecl.clone();
        newStruct.name = instanceName;
        newStruct.isTemplate = false;
        newStruct.templateType = [];

        FunctionSymbol savedFunc = ctx.currentFunction;
        pendingStructs = [];

        new Semantic1(ctx, registry, error, ".", checker).collectStructDecl(newStruct);
        replaceTypesInNode(newStruct, genericNames, validatedConcreteExprs);
        new Semantic2(ctx, error, registry, resolver, checker).resolveStructDecl(newStruct);
        new Semantic3(ctx, error, registry, ".", checker).analyzeStructDecl(newStruct);
        
        ctx.currentFunction = savedFunc;
        checker.structs ~= newStruct;

        return ctx.lookupStruct(instanceName);
    }

    StructSymbol instantiateStruct(StructLit lit, StructSymbol templateSym)
    {
        StructDecl templateDecl = cast(StructDecl) templateSym.declaration;
        if (!templateDecl) return null;

        if (lit.templateType.length != templateDecl.templateType.length)
        {
            error.addError(Diagnostic(
                format("Struct template '%s' expects %d types, got %d.", 
                templateDecl.name, templateDecl.templateType.length, lit.templateType.length), 
                lit.loc));
            return null;
        }

        TypeResolver resolver = new TypeResolver(ctx, error, registry, this);
        TypeExpr[] concreteExprs;
        string[] genericNames;
        string mangleSuffix = "";

        foreach (i, tExpr; lit.templateType)
        {
            Type t = resolver.resolve(tExpr);
            if (!t) return null;

            concreteExprs ~= tExpr;
            mangleSuffix ~= "_" ~ t.toStr();

            if (auto named = cast(NamedTypeExpr) templateDecl.templateType[i])
                genericNames ~= named.name;
        }

        string instanceName = templateDecl.name ~ mangleSuffix;

        if (Symbol s = ctx.lookup(instanceName))
            if (StructSymbol st = cast(StructSymbol) s)
            {
                checker.structs ~= st.declaration;
                return st;
            }
        
        StructDecl newStruct = cast(StructDecl) templateDecl.clone();
        newStruct.name = instanceName;
        newStruct.isTemplate = false;
        newStruct.templateType = [];
        pendingStructs = [];

        FunctionSymbol savedFunc = ctx.currentFunction; // Salva contexto
        replaceTypesInNode(newStruct, genericNames, concreteExprs);
        new Semantic1(ctx, registry, error, ".", checker).collectStructDecl(newStruct);
        new Semantic2(ctx, error, registry, null, checker).resolveStructDecl(newStruct);
        new Semantic3(ctx, error, registry, ".", checker).analyzeStructDecl(newStruct);

        ctx.currentFunction = savedFunc;        
        checker.structs ~= newStruct;
        checker.structs ~= pendingStructs;

        return ctx.lookupStruct(instanceName);
    }

    FunctionSymbol instantiate(CallExpr expr, FunctionSymbol templateSym)
    {
        FuncDecl templateDecl = cast(FuncDecl) templateSym.declaration;
        if (!templateDecl) return null;

        if (expr.templateType.length != templateDecl.templateType.length)
        {
            error.addError(Diagnostic(
                format("Template '%s' expects %d types, got %d.", 
                templateDecl.name, templateDecl.templateType.length, expr.templateType.length), 
                expr.loc));
            return null;
        }

        TypeResolver resolver = new TypeResolver(ctx, error, registry, this);
        TypeExpr[] concreteExprs;
        string[] genericNames;
        string mangleSuffix = "";

        foreach (i, tExpr; expr.templateType)
        {
            Type t = resolver.resolve(tExpr);
            if (!t) return null;

            concreteExprs ~= tExpr;
            mangleSuffix ~= "_" ~ t.toStr();

            if (auto named = cast(NamedTypeExpr) templateDecl.templateType[i])
                genericNames ~= named.name;
        }

        string instanceName = templateDecl.name ~ mangleSuffix;

        if (Symbol s = ctx.lookup(instanceName))
            if (auto fn = cast(FunctionSymbol) s) return fn;

        // writeln("TEMPLATE FUNC: ");
        // templateDecl.print();

        FuncDecl newFunc = cast(FuncDecl) templateDecl.clone();
        newFunc.name = instanceName;
        newFunc.isTemplate = false;
        newFunc.templateType = [];

        replaceTypesInNode(newFunc, genericNames, concreteExprs);
        FunctionSymbol savedFunc = ctx.currentFunction; // Salva contexto
        new Semantic2(ctx, error, registry, null, checker).resolveFunctionDecl(newFunc);
        
        if (checker.funcAnalyzer)
            checker.funcAnalyzer.analyzeFunction(newFunc);

        ctx.currentFunction = savedFunc;

        checker.funcs ~= newFunc;
        return cast(FunctionSymbol) ctx.lookup(instanceName);
    }

    private TypeExpr resolveTypeReplacement(TypeExpr t, string[] genNames, TypeExpr[] concExprs)
    {
        if (!t) return null;

        // Caso base: É um nome (T)
        if (auto named = cast(NamedTypeExpr) t)
        {
            foreach(i, name; genNames)
                if (named.name == name)
                    return cast(TypeExpr) concExprs[i].clone(); // Substitui!
        }
        // Recursão: Ponteiro (T*)
        else if (auto ptr = cast(PointerTypeExpr) t)
        {
            auto sub = resolveTypeReplacement(ptr.pointeeType, genNames, concExprs);
            if (sub) return new PointerTypeExpr(sub, t.loc);
        }
        // Recursão: Array (T[])
        else if (auto arr = cast(ArrayTypeExpr) t)
        {
            auto sub = resolveTypeReplacement(arr.elementType, genNames, concExprs);
            if (sub) return new ArrayTypeExpr(sub, t.loc, arr.length);
        }
        else if (auto ge = cast(GenericTypeExpr) t)
        {
            TypeExpr[] resolvedArgs;
            bool anyChange = false;

            foreach(arg; ge.typeArgs)
            {
                auto resolved = resolveTypeReplacement(arg, genNames, concExprs);
                if (resolved) {
                    resolvedArgs ~= resolved;
                    anyChange = true;
                } else {
                    resolvedArgs ~= arg;
                }
            }

            auto newGe = new GenericTypeExpr(ge.baseType, resolvedArgs, t.loc);
            TypeResolver resolver = new TypeResolver(ctx, error, registry, this); 
            Type resolvedType = resolver.resolve(newGe);

            if (resolvedType)
                return new NamedTypeExpr(resolvedType.toStr(), t.loc);
            
            return newGe;
        }
        return null;
    }

    private void replaceTypesInNode(Node node, string[] genNames, TypeExpr[] concExprs)
    {
        if (!node) return;
    
        void tryUpdate(ref TypeExpr typeField, ref Type resolvedField)
        {
            if (auto newT = resolveTypeReplacement(typeField, genNames, concExprs))
            {
                typeField = newT;
                resolvedField = null;
            }
        }
    
        // Navegação simples pelos nós que importam
        if (auto v = cast(VarDecl) node) {
            tryUpdate(v.type, v.resolvedType);
            replaceTypesInNode(v.value.get!Node, genNames, concExprs);
        }
        else if (auto s = cast(StructDecl) node) {
            // Substitui tipos nos campos (T value -> int value)
            foreach(ref field; s.fields) {
                tryUpdate(field.type, field.resolvedType);
                replaceTypesInNode(field.defaultValue, genNames, concExprs);
            }
            // Substitui tipos nos métodos
            foreach(key, overloads; s.methods) {
                foreach(ref method; overloads)
                    replaceTypesInNode(method.funcDecl, genNames, concExprs);
            }
        }
        else if (auto f = cast(FuncDecl) node) {
            tryUpdate(f.type, f.resolvedType);
            foreach(ref arg; f.args) {
                tryUpdate(arg.type, arg.resolvedType);
                replaceTypesInNode(arg.value, genNames, concExprs);
            }
            replaceTypesInNode(f.body, genNames, concExprs);
        }
        else if (auto c = cast(CastExpr) node) {
            // O cast é crítico: (T)x vira (int)x
            tryUpdate(c.target, c.resolvedType);
            c.type = c.target; // Sincroniza
            replaceTypesInNode(c.from, genNames, concExprs);
        }
        else if (auto b = cast(BlockStmt) node) {
            foreach(s; b.statements) replaceTypesInNode(s, genNames, concExprs);
        }
        else if (auto r = cast(ReturnStmt) node) {
            replaceTypesInNode(r.value, genNames, concExprs);
        }
        else if (auto call = cast(CallExpr) node) {
            // CallExpr pode ter tipos explícitos ou args
            replaceTypesInNode(call.id, genNames, concExprs);
            foreach(arg; call.args) replaceTypesInNode(arg, genNames, concExprs);
            // Se tiver template aninhado cast!(T)
            foreach(ref t; call.templateType) {
                Type dummy = null;
                tryUpdate(t, dummy);
            }
        }
        else if (auto expr = cast(BinaryExpr) node) {
            replaceTypesInNode(expr.left, genNames, concExprs);
            replaceTypesInNode(expr.right, genNames, concExprs);
            tryUpdate(expr.type, expr.resolvedType);
        }
        else if (auto expr = cast(UnaryExpr) node) {
            replaceTypesInNode(expr.operand, genNames, concExprs);
            tryUpdate(expr.type, expr.resolvedType);
        }
        else if (auto expr = cast(AssignDecl) node) {
            replaceTypesInNode(expr.left, genNames, concExprs);
            replaceTypesInNode(expr.right, genNames, concExprs);
            tryUpdate(expr.type, expr.resolvedType);
        }
        else if (auto expr = cast(IndexExpr) node) {
            replaceTypesInNode(expr.target, genNames, concExprs);
            replaceTypesInNode(expr.index, genNames, concExprs);
            tryUpdate(expr.type, expr.resolvedType);
        }
        else if (auto expr = cast(MemberExpr) node) {
            replaceTypesInNode(expr.target, genNames, concExprs);
            tryUpdate(expr.type, expr.resolvedType);
        }
        else if (auto expr = cast(TernaryExpr) node) {
            replaceTypesInNode(expr.condition, genNames, concExprs);
            replaceTypesInNode(expr.trueExpr, genNames, concExprs);
            replaceTypesInNode(expr.falseExpr, genNames, concExprs);
            tryUpdate(expr.type, expr.resolvedType);
        }
        else if (auto lit = cast(ArrayLit) node) {
            foreach(elem; lit.elements) replaceTypesInNode(elem, genNames, concExprs);
            tryUpdate(lit.type, lit.resolvedType);
        }
        else if (auto lit = cast(StructLit) node) {
            foreach(ref init; lit.fieldInits) {
                replaceTypesInNode(init.value, genNames, concExprs);
            }
            tryUpdate(lit.type, lit.resolvedType);
            // Substitui tipos de template
            foreach(ref t; lit.templateType) {
                Type dummy = null;
                tryUpdate(t, dummy);
            }
        }
        else if (auto expr = cast(SizeOfExpr) node) {
            replaceTypesInNode(expr.value, genNames, concExprs);
            if (expr.type_) {
                tryUpdate(expr.type_, expr.resolvedType_);
            }
        }
        else if (auto stmt = cast(IfStmt) node) {
            replaceTypesInNode(stmt.condition, genNames, concExprs);
            replaceTypesInNode(stmt.thenBranch, genNames, concExprs);
            replaceTypesInNode(stmt.elseBranch, genNames, concExprs);
        }
        else if (auto stmt = cast(ForStmt) node) {
            replaceTypesInNode(stmt.init_, genNames, concExprs);
            replaceTypesInNode(stmt.condition, genNames, concExprs);
            replaceTypesInNode(stmt.increment, genNames, concExprs);
            replaceTypesInNode(stmt.body, genNames, concExprs);
        }
        else if (auto stmt = cast(WhileStmt) node) {
            replaceTypesInNode(stmt.condition, genNames, concExprs);
            replaceTypesInNode(stmt.body, genNames, concExprs);
        }
        else if (auto stmt = cast(VersionStmt) node) {
            replaceTypesInNode(stmt.thenBranch, genNames, concExprs);
            replaceTypesInNode(stmt.elseBranch, genNames, concExprs);
            if (stmt.resolvedBranch)
                replaceTypesInNode(stmt.resolvedBranch, genNames, concExprs);
        }
        else if (auto stmt = cast(DeferStmt) node) {
            replaceTypesInNode(stmt.stmt, genNames, concExprs);
        }
        else if (auto decl = cast(TypeDecl) node) {
            tryUpdate(decl.type, decl.resolvedType);
        }
        else if (auto decl = cast(UnionDecl) node) {
            foreach(ref field; decl.fields) {
                tryUpdate(field.type, field.resolvedType);
                replaceTypesInNode(field.defaultValue, genNames, concExprs);
            }
        }
        else if (auto prog = cast(Program) node) {
            foreach(n; prog.body) replaceTypesInNode(n, genNames, concExprs);
        }
    }
}
