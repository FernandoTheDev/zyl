module frontend.semantic.function_analyzer;

import frontend;
import common.reporter;

class FunctionAnalyzer
{
    Context ctx;
    TypeChecker checker;
    DiagnosticError error;
    Semantic3 sema3;

    this(Context ctx, TypeChecker checker, DiagnosticError error, Semantic3 sema3)
    {
        this.ctx = ctx;
        this.checker = checker;
        this.error = error;
        this.sema3 = sema3;
    }

    void analyzeFunction(FuncDecl decl)
    {   
        Type[] args = decl.args.map!(x => x.resolvedType).array;
        FunctionSymbol funcSym = ctx.findFunction(decl.name, args, decl.resolvedType);
        if (funcSym is null)
            return;

        ctx.enterFunction(funcSym);

        if (decl.body !is null) {
            foreach (i, ref param; decl.args) {
                if (!ctx.addVariable(param.name, param.resolvedType, false, decl.loc))
                    error.addError(Diagnostic(
                            format("Duplicate parameter '%s'", param.name),
                            decl.loc
                    ));
            }
            
            if (decl.body.statements.length >= 0)
            {
                if (funcSym.declaration.isVarArg)
                    ctx.addVariable("_vacount", new PrimitiveType(BaseType.Int), true, decl.loc);
                    
                sema3.analyzeBlockStmt(decl.body, true);
                // Verifica se função não-void tem return
                if (!decl.resolvedType.isVoid())
                {
                    if (!sema3.hasReturn(decl.body))
                    {
                        error.addError(Diagnostic(
                                format("The function '%s' needs to return '%s'.",
                                decl.name, decl.resolvedType.toStr()),
                                decl.loc
                        ));
                    }
                }
            }
        }

        ctx.exitFunction();
    }
}
