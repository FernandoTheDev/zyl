module frontend.semantic.semantic3;

import frontend;
import common.reporter;

class Semantic3
{
    Context ctx;
    TypeChecker checker;
    DiagnosticError error;
    FunctionAnalyzer funcAnalyzer;
    TypeRegistry registry;
    string pathRoot;

    this(Context ctx, DiagnosticError error, TypeRegistry registry, string pathRoot, TypeChecker checker)
    {
        this.ctx = ctx;
        this.error = error;
        this.checker = checker;
        this.funcAnalyzer = new FunctionAnalyzer(ctx, this.checker, this.error, this);
        this.checker.funcAnalyzer = this.funcAnalyzer;
        this.registry = registry;
        this.pathRoot = pathRoot;
    }

    pragma(inline, true)
    void reportError(string message, Loc loc, Suggestion[] suggestions = null)
    {
        error.addError(Diagnostic(message, loc, suggestions));
    }

    void analyze(Program program)
    {
        foreach (node; program.body)
            analyzeDeclaration(node);

        Node[] body;
        if (checker.structs.length > 0)
            body ~= checker.structs;
        
        if (checker.funcs.length > 0)
            body ~= checker.funcs;

        body ~= program.body;
        program.body = body;
    }

    Node analyzeDeclaration(Node node)
    {
        if (auto varDecl = cast(VarDecl) node)
            analyzeVarDecl(varDecl, true);
        else if (auto funcDecl = cast(FuncDecl) node)
            this.funcAnalyzer.analyzeFunction(funcDecl);
        else if (auto versionStmt = cast(VersionStmt) node)
            analyzeVersionStmt(versionStmt, true);
        else if (auto structDecl = cast(StructDecl) node)
            analyzeStructDecl(structDecl);
        else if (auto un = cast(UnionDecl) node)
            analyzeUnionDecl(un);
        else if (auto enm = cast(EnumDecl) node)
            return enm;
        return node;
    }

    void analyzeUnionDecl(UnionDecl decl)
    {
        UnionSymbol sym = ctx.lookupUnion(decl.name);
        if (sym is null)
        {
            reportError(format("Union '%s' not found in context.", decl.name), decl.loc);
            return;
        }

        foreach (ref field; decl.fields)
        {
            if (field.defaultValue !is null)
            {
                Type valueType = checker.checkExpression(field.defaultValue);
                if (!field.resolvedType.isCompatibleWith(valueType))
                {
                    reportError(
                        format("Default value for field '%s' has incompatible type: expected '%s', got '%s'",
                               field.name, field.resolvedType.toStr(), valueType.toStr()),
                        field.defaultValue.loc
                    );
                }
            }
        }
    }

    void analyzeStructDecl(StructDecl decl)
    {
        StructSymbol structSym = ctx.lookupStruct(decl.name);
        if (structSym is null)
        {
            reportError(format("Struct '%s' not found in context.", decl.name), decl.loc);
            return;
        }

        if (decl.isTemplate)
            return;
        
        foreach (ref field; decl.fields)
        {
            if (field.defaultValue !is null)
            {
                Type valueType = checker.checkExpression(field.defaultValue);
                if (!field.resolvedType.isCompatibleWith(valueType))
                {
                    reportError(
                        format("Default value for field '%s' has incompatible type: expected '%s', got '%s'",
                               field.name, field.resolvedType.toStr(), valueType.toStr()),
                        field.defaultValue.loc
                    );
                }
            }
        }

        foreach (methodName, overloads; decl.methods)
            foreach (ref method; overloads)
                analyzeStructMethod(structSym, method);
    }

    void analyzeStructMethod(StructSymbol structSym, ref StructMethod method)
    {
        FuncDecl funcDecl = method.funcDecl;
        foreach (ref param; funcDecl.args)
        {
            if (param.value !is null)
            {
                // Type check do valor padrão
                Type valueType = checker.checkExpression(param.value);
                // Verifica compatibilidade
                if (!param.resolvedType.isCompatibleWith(valueType))
                {
                    reportError(
                        format("Default value for parameter '%s' has incompatible type: expected '%s', got '%s'",
                               param.name, param.resolvedType.toStr(), valueType.toStr()),
                        param.value.loc
                    );
                }
            }
        }
    
        if (funcDecl.body !is null)
        {
            ctx.enterStruct(structSym);
            
            Type[] paramTypes;
            foreach (param; funcDecl.args)
                paramTypes ~= param.resolvedType;
            
            auto funcSym = new FunctionSymbol(
                funcDecl.name,
                paramTypes,
                funcDecl.resolvedType,
                funcDecl,
                funcDecl.loc
            );
            
            ctx.enterFunction(funcSym);
            
            foreach (i, param; funcDecl.args)
            {
                if (!ctx.addVariable(param.name, param.resolvedType, false, param.loc))
                {
                    reportError(
                        format("Parameter '%s' already defined", param.name),
                        param.loc
                    );
                }
            }
            
            Program program = new Program(funcDecl.body.statements);
            new Semantic1(ctx, registry, error, pathRoot, checker).analyze(program);
            new Semantic2(ctx, error, registry, null, checker).analyze(program);
        
            analyzeBlockStmt(funcDecl.body);
            
            if (!method.isConstructor && !funcDecl.resolvedType.isVoid())
                if (!hasReturn(funcDecl.body))
                    reportError(
                        format("Method '%s' must return a value of type '%s'",
                               funcDecl.name, funcDecl.resolvedType.toStr()),
                        funcDecl.loc
                    );
            
            ctx.exitFunction();
            ctx.exitStruct();
        }
    }

    Node analyzeAssignDecl(Node node)
    {
        AssignDecl decl = cast(AssignDecl) node;
        Type leftType = checker.checkExpression(decl.left);
        Type rightType = checker.checkExpression(decl.right);
        
        if (decl.op == "+=")
            if (StructType st = cast(StructType) leftType)
                if (st.hasMethod("opAddAssign"))
                {
                    Node call = new CallExpr(new MemberExpr(decl.left, "opAddAssign", decl.left.loc), [decl.right], 
                        decl.loc);
                    analyzeCall(cast(CallExpr)call);
                    return call;
                }

        checker.checkTypeComp(leftType, rightType, decl.loc);

        if (decl.op != "=")
            if (!isValidCompoundAssignment(leftType, rightType, decl.op))
                reportError(format("The operator '%s' is invalid for types '%s' and '%s'.",
                        decl.op, leftType.toStr(), rightType.toStr()), decl.loc);
        
        decl.resolvedType = leftType;
        return decl;
    }

    bool isValidCompoundAssignment(Type left, Type right, string op)
    {
        PrimitiveType primLeft = cast(PrimitiveType) left;
        PrimitiveType primRight = cast(PrimitiveType) right;

        if (primLeft is null || primRight is null)
            return false;

        if (op == "+=" || op == "-=" || op == "*=" || op == "/=" || op == "%=")
            return primLeft.isNumeric() && primRight.isNumeric();

        if (op == "&=" || op == "|=" || op == "^=" || op == "<<=" || op == ">>=")
            return isIntegerType(primLeft.baseType) && isIntegerType(primRight.baseType);

        return false;
    }

    bool isIntegerType(BaseType type)
    {
        return type == BaseType.Int || type == BaseType.Long;
    }

    void analyzeVarDecl(VarDecl decl, bool isGlobal = false)
    {
        decl.isGlobal = isGlobal;
        Node init_ = decl.value.get!Node;
        VarSymbol sym = ctx.lookupVariable(decl.id);

        if (init_ !is null)
        {
            Type initType = checker.checkExpression(init_);
            if (decl.resolvedType !is null)
            {
                checker.makeImplicitCast(init_, decl.resolvedType);
                if (!decl.resolvedType.isCompatibleWith(initType))
                    reportError(format("Incompatible type: expected '%s', got '%s'",
                            decl.resolvedType.toStr(), initType.toStr()), init_.loc);
                
                if (sym !is null && sym.type is null)
                     sym.type = decl.resolvedType;
            }
            else
            {
                decl.resolvedType = initType;
                if (sym !is null)
                    sym.type = initType;
            }
        }
        else if (decl.resolvedType is null)
            reportError(format("The variable '%s' needs a type or initializer.", decl.id), decl.loc);
    }

    void analyzeBlockStmtSema(BlockStmt stmt)
    {
        // corpo analisado
        Program program = new Program(stmt.statements);
        new Semantic1(ctx, registry, error, pathRoot, checker).analyze(program);
        new Semantic2(ctx, error, registry, null, checker).analyze(program);
    }

    void analyzeBlockStmt(BlockStmt stmt, bool sema = false, bool isGlobal = false)
    {
        if (sema)
            analyzeBlockStmtSema(stmt);

        ctx.enterScope("block");

        foreach (i, node; stmt.statements)
            stmt.statements[i] = analyzeStatement(node, sema, isGlobal);

        ctx.exitScope();
    }

    Node analyzeStatement(Node stmt, bool sema = false, bool isGlobal = false)
    {
        if (auto varDecl = cast(VarDecl) stmt)
            analyzeVarDecl(varDecl, isGlobal);
        else if (auto ifStmt = cast(IfStmt) stmt)
            analyzeIfStmt(ifStmt);
        else if (auto whileStmt = cast(WhileStmt) stmt)
            analyzeWhileStmt(whileStmt);
        else if (auto forStmt = cast(ForStmt) stmt)
            analyzeForStmt(forStmt);
        else if (auto returnStmt = cast(ReturnStmt) stmt)
            analyzeReturnStmt(returnStmt);
        else if (auto call = cast(CallExpr) stmt)
            analyzeCall(call);
        else if (auto brkc = cast(BrkOrCntStmt) stmt)
            analyzeBrkOrCntStmt(brkc);
        else if (auto blockStmt = cast(BlockStmt) stmt)
            analyzeBlockStmt(blockStmt, sema);
        else if (auto assign = cast(AssignDecl) stmt)
            return analyzeAssignDecl(assign);
        else if (auto versionStmt = cast(VersionStmt) stmt)
            analyzeVersionStmt(versionStmt);
        else if (UnaryExpr unary = cast(UnaryExpr) stmt) {
            unary.operand.resolvedType = checker.checkExpression(unary.operand);
            unary.resolvedType = unary.operand.resolvedType;
        }
        else if (auto defer = cast(DeferStmt) stmt)
            analyzeDeferStmt(defer);
        else if (auto forStmt = cast(ForEachStmt) stmt)
            analyzeForEachStmt(forStmt);
        else if (auto switchStmt = cast(SwitchStmt) stmt)
            analyzeSwitchStmt(switchStmt);
        return stmt;
    }

    void analyzeSwitchStmt(SwitchStmt stmt)
    {
        Type condType = checker.checkExpression(stmt.condition);
        stmt.condition.resolvedType = condType;

        bool isValidType = false;
        if (auto prim = cast(PrimitiveType) condType)
            isValidType = prim.baseType == BaseType.Int || 
                          prim.baseType == BaseType.Long || 
                          prim.baseType == BaseType.Char ||
                          prim.baseType == BaseType.Bool;
        else if (cast(EnumType) condType)
            isValidType = true;

        if (!isValidType)
        {
            reportError(
                format("Switch condition must be an integer, char, bool, or enum type, got '%s'", 
                       condType.toStr()), 
                stmt.condition.loc,
                [Suggestion("Switch works with: int, long, char, bool, or enum types")]
            );
            return;
        }

        bool hasDefault = false;
        bool[string] seenValues; // Detecta valores duplicados

        foreach (caseStmt; stmt.cases)
        {
            if (caseStmt.isDefault)
            {
                if (hasDefault)
                {
                    reportError(
                        "Switch statement can only have one 'default' case.",
                        caseStmt.loc
                    );
                }
                hasDefault = true;

                ctx.enterLoop();
                ctx.enterScope("default");
                analyzeBlockStmt(caseStmt.body);
                ctx.exitScope();
                ctx.exitLoop();
                continue;
            }

            foreach (value; caseStmt.values)
            {
                Type valueType = checker.checkExpression(value);
                value.resolvedType = valueType;

                if (!condType.isCompatibleWith(valueType))
                {
                    reportError(
                        format("Case value type '%s' incompatible with switch condition type '%s'",
                               valueType.toStr(), condType.toStr()),
                        value.loc,
                        [Suggestion(format("Expected type '%s'", condType.toStr()))]
                    );
                    continue;
                }

                string valueStr = getConstantValue(value);
                if (valueStr !is null)
                {
                    if (valueStr in seenValues)
                    {
                        reportError(
                            format("Duplicate case value: %s", valueStr),
                            value.loc,
                            [Suggestion("Each case value must be unique in the switch statement")]
                        );
                    }
                    else
                        seenValues[valueStr] = true;
                }
            }

            ctx.enterLoop();
            ctx.enterScope("case");
            analyzeBlockStmt(caseStmt.body);
            ctx.exitScope();
            ctx.exitLoop();
        }

        // 4. Warning se não tem default (opcional)
        if (!hasDefault && seenValues.length < 10) // Só avisa se tem poucos cases
        {
            // Nota: Este é um warning opcional, não um erro
            // Você pode remover ou adaptar conforme sua política
        }
    }

    // Helper para extrair valor constante (para detectar duplicatas)
    string getConstantValue(Node node)
    {
        if (auto lit = cast(IntLit) node)
            return to!string(lit.value.get!int);

        if (auto lit = cast(LongLit) node)
            return to!string(lit.value.get!long);

        if (auto lit = cast(CharLit) node)
            return "'" ~ to!string(lit.value.get!char) ~ "'";

        if (auto lit = cast(BoolLit) node)
            return to!string(lit.value.get!bool);

        // Se for um identificador de enum, tenta extrair
        if (auto ident = cast(Identifier) node)
        {
            // Para enums, usamos o nome do membro como chave
            return ident.value.get!string;
        }

        return null; // Não é constante ou não suportado
    }

    void analyzeDeferStmt(DeferStmt stmt)
    {
        stmt.stmt = analyzeStatement(stmt.stmt);
    }

    pragma(inline, true);
    void analyzeCall(CallExpr call)
    {
        for (long i; i < call.args.length; i++)
            call.args[i].resolvedType = checker.checkExpression(call.args[i]);
        call.resolvedType = checker.checkExpression(call);
    }

    void analyzeIfStmt(IfStmt stmt)
    {
        // Verifica condição
        if (stmt.condition !is null)
        {
            Type condType = checker.checkExpression(stmt.condition);
            stmt.condition.resolvedType = condType;

            if (!condType.isCompatibleWith(new PrimitiveType(BaseType.Bool)))
                reportError(format("The 'if' condition must be logical, it was obtained by '%s'.",
                        condType.toStr()), stmt.condition.loc);
        }


        if (stmt.thenBranch !is null)
            analyzeStatement(stmt.thenBranch, true);

        if (stmt.elseBranch !is null)
            analyzeStatement(stmt.elseBranch, true);
    }

    pragma(inline, true);
    void analyzeVersionStmt(VersionStmt stmt, bool isGlobal = false)
    {
        if (stmt.resolvedBranch !is null)
            analyzeBlockStmt(stmt.resolvedBranch, false, isGlobal);
    }

    void analyzeWhileStmt(WhileStmt stmt)
    {
        Type condType = checker.checkExpression(stmt.condition);
        if (!condType.isCompatibleWith(new PrimitiveType(BaseType.Bool)))
            reportError("The condition in the 'while' loop must be logical.", stmt.condition.loc);

        ctx.enterLoop();
        analyzeStatement(stmt.body, true);
        ctx.exitLoop();
    }

    void analyzeForEachStmt(ForEachStmt stmt)
    {
        Type iterableType = checker.checkExpression(stmt.iterable);
        stmt.iterable.resolvedType = iterableType;

        StructType structType = cast(StructType) iterableType;
        if (structType is null)
        {
            if (PointerType ptrType = cast(PointerType) iterableType)
            {
                structType = cast(StructType) ptrType.pointeeType;
                if (structType is null)
                {
                    reportError(
                        format("Cannot iterate over type '%s'. The iterable must be a struct or pointer to struct with "
                             ~ "'opIter' and 'opNext' methods.",
                               iterableType.toStr()),
                        stmt.iterable.loc,
                        [Suggestion("Define a struct with 'opIter' and 'opNext' methods for iteration support.")]
                    );
                    return;
                }
            }
            else
            {
                reportError(
                    format(
                    "Cannot iterate over type '%s'. The iterable must be a struct with 'opIter' and 'opNext' methods.",
                           iterableType.toStr()),
                    stmt.iterable.loc,
                    [
                        Suggestion(
                            "Foreach requires a struct type. Example: 'struct Container { T* opNext(...) { ... } }'"),
                        Suggestion(format("If '%s' should be iterable, implement the iterator protocol.", 
                            iterableType.toStr()))
                    ]
                );
                return;
            }
        }

        if (!structType.hasMethod("opIter"))
        {
            reportError(
                format("Struct '%s' cannot be used in foreach: missing 'opIter' method.",
                       structType.name),
                stmt.iterable.loc,
                [
                    Suggestion(format("Add 'opIter' method to struct '%s':", structType.name)),
                    Suggestion(format("    %s* opIter(%s* self) { return self }", structType.name, structType.name))
                ]
            );
            return;
        }

        if (!structType.hasMethod("opNext"))
        {
            reportError(
                format("Struct '%s' cannot be used in foreach: missing 'opNext' method.",
                       structType.name),
                stmt.iterable.loc,
                [
                    Suggestion(format("Add 'opNext' method to struct '%s':", structType.name)),
                    Suggestion("    T* opNext(" ~ structType.name ~ "* self) { ... }")
                ]
            );
            return;
        }

        StructMethod* method = structType.getMethod("opNext");
        Type opNextType = method.funcDecl.resolvedType;
        if (opNextType is null)
        {
            reportError(
                format("Method 'opNext' in struct '%s' has invalid signature.", structType.name),
                stmt.iterable.loc
            );
            return;
        }

        Type iteratorType = opNextType;

        // if (stmt.iterVarType !is null)
        // {
        //     Type declaredType = checker.(stmt.iterVarType);
        //     if (!declaredType.isCompatibleWith(iteratorType))
        //     {
        //         reportError(
        //             format("Iterator variable type mismatch: declared '%s', but opNext returns '%s'",
        //                    declaredType.toStr(), iteratorType.toStr()),
        //             stmt.loc,
        //             [Suggestion(format("Change iterator type to '%s' or remove explicit type declaration",
        //                 iteratorType.toStr()))]
        //         );
        //         return;
        //     }
        //     iteratorType = declaredType;
        // }

        ctx.enterLoop();
        ctx.enterScope("foreach");

        if (!ctx.addVariable(stmt.iterVar, iteratorType, true, stmt.loc))
        {
            reportError(
                format("Variable '%s' is already defined in this scope.", stmt.iterVar),
                stmt.loc
            );
        }

        analyzeStatement(stmt.body, true);

        ctx.exitScope();
        ctx.exitLoop();

        stmt.resolvedType = iteratorType;
    }

    void analyzeForStmt(ForStmt stmt)
    {
        VarDecl decl = null;

        // Analisa inicializador
        if (stmt.init_ !is null) {
            analyzeStatement(stmt.init_);
            if (stmt.init_.kind == NodeKind.VarDecl)
                decl = cast(VarDecl) stmt.init_;
                ctx.addVariable(decl.id, stmt.init_.resolvedType, decl.isConst, decl.loc);
        }

        // Analisa condição
        if (stmt.condition !is null)
        {
            Type condType = checker.checkExpression(stmt.condition);
            if (!condType.isCompatibleWith(new PrimitiveType(BaseType.Bool)))
                reportError("The condition in the 'for' loop must be logical.", stmt.condition.loc);
        }

        // Analisa incremento
        if (stmt.increment !is null)
            checker.checkExpression(stmt.increment);

        // Analisa corpo
        ctx.enterLoop();
        analyzeStatement(stmt.body, true);
        ctx.exitLoop();
    }

    void analyzeReturnStmt(ReturnStmt stmt)
    {
        if (!ctx.isInFunction())
        {
            reportError("Using 'return' outside of a function.", stmt.loc);
            return;
        }

        Type returnType = stmt.value !is null ?
            checker.checkExpression(stmt.value) : VoidType.instance();
        Type expectedType = ctx.currentFunction.returnType;

        if (expectedType.toStr() != returnType.toStr())
            if (!expectedType.isCompatibleWith(returnType))
                reportError(format("Incompatible return type: expected '%s', received '%s'",
                        expectedType.toStr(), returnType.toStr()), stmt.loc);
    }

    void analyzeBrkOrCntStmt(BrkOrCntStmt stmt)
    {
        if (!ctx.isInLoop())
            reportError(format("'%s' cannot be used outside of a loop..", stmt.isBreak ? "break" : "continue"), 
                stmt.loc);
    }

    bool hasReturn(BlockStmt block)
    {
        foreach (stmt; block.statements)
        {
            if (cast(ReturnStmt) stmt)
                return true;

            // Verifica em if/else
            if (auto ifStmt = cast(IfStmt) stmt)
            {
                if (ifStmt.elseBranch !is null)
                {
                    bool thenHas = false, elseHas = false;

                    if (auto thenBlock = cast(BlockStmt) ifStmt.thenBranch)
                        thenHas = hasReturn(thenBlock);

                    if (auto elseBlock = cast(BlockStmt) ifStmt.elseBranch)
                        elseHas = hasReturn(elseBlock);

                    if (thenHas && elseHas)
                        return true;
                }
            }
        }
        return false;
    }
}
