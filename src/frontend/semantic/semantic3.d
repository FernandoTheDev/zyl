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

    this(Context ctx, DiagnosticError error, TypeRegistry registry)
    {
        this.ctx = ctx;
        this.error = error;
        this.checker = new TypeChecker(ctx, error, registry);
        this.funcAnalyzer = new FunctionAnalyzer(ctx, this.checker, this.error, this);
        this.checker.funcAnalyzer = this.funcAnalyzer;
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
            analyzeDeclaration(node);
    }

    Node analyzeDeclaration(Node node)
    {
        if (auto varDecl = cast(VarDecl) node) {
            analyzeVarDecl(varDecl, true);
            return varDecl;
        }
        else if (auto funcDecl = cast(FuncDecl) node) {
            this.funcAnalyzer.analyzeFunction(funcDecl);
            return funcDecl;
        } else if (auto versionStmt = cast(VersionStmt) node) {
            analyzeVersionStmt(versionStmt, true);
            return versionStmt;
        }
        else if (auto structDecl = cast(StructDecl) node) {
            analyzeStructDecl(structDecl);
            return structDecl;
        }
        return null;
    }

    // Nova função para analisar struct declarations
    void analyzeStructDecl(StructDecl decl)
    {
        StructSymbol structSym = ctx.lookupStruct(decl.name);
        if (structSym is null)
        {
            reportError(format("Struct '%s' not found in context.", decl.name), decl.loc);
            return;
        }

        // 1. Valida valores padrão dos campos
        foreach (ref field; decl.fields)
        {
            if (field.defaultValue !is null)
            {
                // Type check do valor padrão
                Type valueType = checker.checkExpression(field.defaultValue);

                // Verifica compatibilidade
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

        // 2. Analisa métodos (incluindo construtores)
        foreach (ref method; decl.methods)
            analyzeStructMethod(structSym, method);
    }

    // Analisa um método de struct
    void analyzeStructMethod(StructSymbol structSym, ref StructMethod method)
    {
        FuncDecl funcDecl = method.funcDecl;
        
        // 1. Valida valores padrão dos parâmetros
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
    
        // 2. Se o método tem corpo, analisa ele
        if (funcDecl.body !is null)
        {
            // Entra no contexto da struct
            ctx.enterStruct(structSym);
            
            // Cria um FunctionSymbol temporário para o método
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
            
            // Entra no contexto da função
            ctx.enterFunction(funcSym);
            
            // Adiciona parâmetros ao escopo
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
            
            // Adiciona 'this' ao escopo (referência à instância da struct)
            // if (!ctx.addVariable("this", structSym.structType, true, funcDecl.loc))
            //     reportError("Failed to add 'this' to scope", funcDecl.loc);

            Program program = new Program(funcDecl.body.statements);
            new Semantic1(ctx, registry, error).analyze(program);
            new Semantic2(ctx, error, registry).analyze(program);
        
            // Analisa corpo do método
            analyzeBlockStmt(funcDecl.body);
            
            // Verifica se métodos não-void têm return
            if (!method.isConstructor && !funcDecl.resolvedType.isVoid())
                if (!hasReturn(funcDecl.body))
                    reportError(
                        format("Method '%s' must return a value of type '%s'",
                               funcDecl.name, funcDecl.resolvedType.toStr()),
                        funcDecl.loc
                    );
            
            // Sai dos contextos
            ctx.exitFunction();
            ctx.exitStruct();
        }
    }

    void analyzeAssignDecl(AssignDecl decl)
    {
        Type leftType = checker.checkExpression(decl.left);
        Type rightType = checker.checkExpression(decl.right);

        checker.checkTypeComp(leftType, rightType, decl.loc);

        if (decl.op != "=")
            if (!isValidCompoundAssignment(leftType, rightType, decl.op))
                reportError(format("The operator '%s' is invalid for types '%s' and '%s'.",
                        decl.op, leftType.toStr(), rightType.toStr()), decl.loc);
        
        decl.resolvedType = leftType;
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
        // Analisa inicializador
        decl.isGlobal = isGlobal;
        Node init_ = decl.value.get!Node;
        VarSymbol sym = ctx.lookupVariable(decl.id);
        if (init_ !is null)
        {
            Type initType = checker.checkExpression(init_);
            if (decl.resolvedType !is null)
            {
                if (!decl.resolvedType.isCompatibleWith(initType))
                    reportError(format("Incompatible type: expected '%s', got '%s'",
                            decl.resolvedType.toStr(), initType.toStr()), init_.loc);

                // se são compativeis então atualiza o tipo do init pelo tipo resolvido da variavel
                // writeln(init_.resolvedType.toStr());
                init_.resolvedType = decl.resolvedType;
                // writeln(init_.resolvedType.toStr());

                if (sym !is null)
                {
                    if (!initType.isArray())
                    {
                        sym.type = initType;
                        decl.resolvedType = initType;
                    }
                }
            }
            else
            {
                // Inferência de tipo
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
        new Semantic1(ctx, registry, error).analyze(program);
        new Semantic2(ctx, error, registry).analyze(program);
    }

    void analyzeBlockStmt(BlockStmt stmt, bool sema = false, bool isGlobal = false)
    {
        if (sema)
            analyzeBlockStmtSema(stmt);

        ctx.enterScope("block");

        foreach (node; stmt.statements)
            analyzeStatement(node, sema, isGlobal);

        ctx.exitScope();
    }

    Node analyzeStatement(Node stmt, bool sema = false, bool isGlobal = false)
    {
        if (auto varDecl = cast(VarDecl) stmt) {
            analyzeVarDecl(varDecl, isGlobal);
            return varDecl;
        }
        else if (auto ifStmt = cast(IfStmt) stmt) {
            analyzeIfStmt(ifStmt);
            return ifStmt;
        }
        else if (auto whileStmt = cast(WhileStmt) stmt)
            analyzeWhileStmt(whileStmt);
        else if (auto forStmt = cast(ForStmt) stmt) {
            analyzeForStmt(forStmt);
            return forStmt;
        }
        else if (auto returnStmt = cast(ReturnStmt) stmt) {
            analyzeReturnStmt(returnStmt);
            return stmt;
        }
        else if (auto call = cast(CallExpr) stmt) {
            analyzeCall(call);
            return call;
        }
        else if (auto brkc = cast(BrkOrCntStmt) stmt)
            analyzeBrkOrCntStmt(brkc);
        else if (auto blockStmt = cast(BlockStmt) stmt) {
            analyzeBlockStmt(blockStmt, sema);
            return blockStmt;
        }
        else if (auto assign = cast(AssignDecl) stmt) {
            analyzeAssignDecl(assign);
            return assign;
        }
        else if (auto versionStmt = cast(VersionStmt) stmt) {
            analyzeVersionStmt(versionStmt);
            return versionStmt;
        }
        else if (UnaryExpr unary = cast(UnaryExpr) stmt) {
            unary.operand.resolvedType = checker.checkExpression(unary.operand);
            unary.resolvedType = unary.operand.resolvedType;
            return unary;
        }
        return null;
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

        if (!returnType.isCompatibleWith(expectedType))
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
