module frontend.semantic.type_checker;

import frontend;
import common.reporter;

class TypeChecker
{
    Context ctx;
    DiagnosticError error;
    FunctionAnalyzer funcAnalyzer;
    TypeRegistry registry;
    FuncDecl[] funcs;
    StructDecl[] structs;
    StructDecl[] qeue;

    this(Context ctx, DiagnosticError error, TypeRegistry registry)
    {
        this.ctx = ctx;
        this.error = error;
        this.registry = registry;
    }

    Type checkExpression(Node expr)
    {
        if (expr is null)
            return VoidType.instance();

        if (expr.resolvedType !is null)
            return expr.resolvedType;

        Type type = checkExpressionInternal(expr);
        expr.resolvedType = type;
        return type;
    }


    pragma(inline, true)
    void reportError(string message, Loc loc, Suggestion[] suggestions = null)
    {
        error.addError(Diagnostic(message, loc, suggestions));
    }

    bool checkType(Type left, Type right, Loc loc, bool strict = true)
    {
        if (left is null || right is null)
            return false;
        if (!left.isCompatibleWith(right, strict))
        {
            reportError(format("Incompatible types, expected '%s' received '%s'.", left.toStr(), right.toStr()), loc);
            return false;
        }
        return true;
    }

    bool checkTypeComp(Type left, Type right, Loc loc, bool strict = true)
    {
        if (!left.isCompatibleWith(right, strict))
        {
            reportError(format("Incompatible types, a type compatible with '%s' was expected but '%s' was received.", 
                left.toStr(), right.toStr()), loc);
            return false;
        }
        return true;
    }

    bool checkTypeBoth(Type left, Type right, Loc loc, bool strict = true)
    {
        if (!left.isCompatibleWith(right, strict) || !right.isCompatibleWith(left, strict))
        {
            reportError("Both values ​must be compatible with each other.", loc);
            return false;
        }
        return true;
    }

private:
    Type checkExpressionInternal(Node expr)
    {
        // Literais
        if (auto lit = cast(IntLit) expr)
            return new PrimitiveType(BaseType.Int);

        if (auto lit = cast(LongLit) expr)
            return new PrimitiveType(BaseType.Long);

        if (auto lit = cast(FloatLit) expr)
            return new PrimitiveType(BaseType.Float);

        if (auto lit = cast(DoubleLit) expr)
            return new PrimitiveType(BaseType.Double);

        if (auto lit = cast(StringLit) expr)
            return new PointerType(new PrimitiveType(BaseType.Char));

        if (auto lit = cast(BoolLit) expr)
            return new PrimitiveType(BaseType.Bool);

        if (auto lit = cast(NullLit) expr)
            return new PointerType(new PrimitiveType(BaseType.Void));

        if (auto lit = cast(CharLit) expr)
            return new PrimitiveType(BaseType.Char);

        if (auto structLit = cast(StructLit) expr)
            return checkStructLit(structLit);

        if (auto ident = cast(Identifier) expr)
            return checkIdentifier(ident);

        if (auto binary = cast(BinaryExpr) expr)
            return checkBinaryExpr(binary, expr);
        
        if (auto unary = cast(UnaryExpr) expr)
            return checkUnaryExpr(unary);
        
        if (auto assign = cast(AssignDecl) expr)
            return checkAssignDecl(assign);

        if (auto call = cast(CallExpr) expr)
            return checkCallExpr(call);

        if (auto index = cast(IndexExpr) expr)
            return checkIndexExpr(index);

        if (auto member = cast(MemberExpr) expr)
            return checkMemberExpr(member);

        if (auto arr = cast(ArrayLit) expr)
            return checkArrayLiteral(arr);

        if (auto ternary = cast(TernaryExpr) expr)
            return checkTernary(ternary);

        if (auto cst = cast(CastExpr) expr)
            return checkCastExpr(cst);

        if (auto sizeof = cast(SizeOfExpr) expr)
            return checkSizeof(sizeof);

        reportError("Unknown expression in type checking.", expr.loc);
        return new PrimitiveType(BaseType.Any);
    }

    public void makeImplicitCast(ref Node node, Type targetType)
    {
        Node cast_ = implicitCast(node, targetType);
        if (cast_ != node)
            node = cast_;
    }

    public Node implicitCast(Node node, Type targetType)
    {
        Type sourceType = node.resolvedType;

        if (targetType == sourceType)
            return node;

        if (targetType is null)
            return node;

        if (!targetType.isCompatibleWith(sourceType, false))
            return node;
        
        if (isNumeric(sourceType) && isNumeric(targetType))
        {
            auto castNode = new CastExpr(null, node, node.loc);
            castNode.resolvedType = targetType; 
            return castNode;
        }

        if (targetType.toStr() == "void*" && sourceType.isPointer()) 
        {
             auto castNode = new CastExpr(null, node, node.loc);
             castNode.resolvedType = targetType;
             return castNode;
        }

        if (sourceType.toStr() == "null" && targetType.isPointer())
             return node;

        return node;
    }

    int getRank(Type t) 
    {
        if (PrimitiveType p = cast(PrimitiveType) t)
            return TYPE_HIERARCHY.get(p.baseType, 0);
        return 0;
    }

    bool isNumeric(Type t)
    {
        return getRank(t) > 0;
    }

    Type checkStructLit(StructLit lit)
    {
        StructSymbol structSym = ctx.lookupStruct(lit.structName);
        if (structSym is null)
        {
            reportError(format("Struct '%s' not found", lit.structName), lit.loc);
            lit.resolvedType = new PrimitiveType(BaseType.Any);
            return new PrimitiveType(BaseType.Any);
        }

        if (lit.isTemplate || lit.templateType.length > 0)
        {
            if (!structSym.isTemplate) {
                reportError(format("Struct '%s' is not a template.", lit.structName), lit.loc);
                return new PrimitiveType(BaseType.Any);
            }

            auto instantiator = new TemplateInstantiator(ctx, error, registry, this);
            StructSymbol concreteSym = instantiator.instantiateStruct(lit, structSym);
            
            if (concreteSym is null) return new PrimitiveType(BaseType.Any);

            lit.structName = concreteSym.name;
            lit.isTemplate = false;
            lit.templateType = [];
            
            structSym = concreteSym;
        }
        
        StructType structType = structSym.structType;
        lit.mangledName = structSym.declaration.mangledName;
        structType.mangledName = lit.mangledName;
        lit.resolvedType = structType;
        
        // 1. Se for chamada de construtor: User("John")
        if (lit.isConstructorCall)
        {
            auto ctor = structType.getConstructor();
            if (ctor is null)
            {
                reportError(
                    format("Struct '%s' does not have a constructor", lit.structName),
                    lit.loc
                );
                return lit.resolvedType;
            }
            
            // Valida número de argumentos
            if (lit.fieldInits.length != ctor.funcDecl.args.length)
            {
                reportError(
                    format("Constructor expects %d arguments, got %d",
                           ctor.funcDecl.args.length, lit.fieldInits.length),
                    lit.loc
                );
                return lit.resolvedType;
            }
            
            // Valida tipos dos argumentos
            foreach (i, init; lit.fieldInits)
            {
                Type argType = checkExpression(init.value);
                Type expectedType = ctor.funcDecl.args[i].resolvedType;
                
                if (!expectedType.isCompatibleWith(argType))
                {
                    reportError(
                        format("Argument %d: expected '%s', got '%s'",
                               i + 1, expectedType.toStr(), argType.toStr()),
                        init.value.loc
                    );
                    return lit.resolvedType;
                }
            }
        }
        // 2. Se for inicialização posicional: Test{"John", 17}
        else if (lit.isPositional)
        {
            if (lit.fieldInits.length > structType.fieldCount())
            {
                reportError(
                    format("Too many initializers: struct '%s' has %d fields, got %d",
                           lit.structName, structType.fieldCount(), lit.fieldInits.length),
                    lit.loc
                );
                return lit.resolvedType;
            }
            
            // Valida cada campo na ordem
            foreach (i, ref init; lit.fieldInits)
            {
                if (i >= structType.fields.length)
                    break;
                
                StructField field = structType.fields[i];
                Type valueType = checkExpression(init.value);
                makeImplicitCast(init.value, field.resolvedType);
                valueType = init.value.resolvedType;

                if (!field.resolvedType.isCompatibleWith(valueType))
                {
                    reportError(
                        format("Field '%s': expected '%s', got '%s'",
                               field.name, field.resolvedType.toStr(), valueType.toStr()),
                        init.value.loc
                    );
                    return lit.resolvedType;
                }
            }
        }
        // 3. Se for inicialização nomeada: Test{.name="John", .age=17}
        else
        {
            bool[string] initializedFields;
            
            foreach (init; lit.fieldInits)
            {
                // Verifica se o campo existe
                if (!structType.hasField(init.name))
                {
                    reportError(
                        format("Struct '%s' does not have field '%s'",
                               lit.structName, init.name),
                        init.loc
                    );
                    continue;
                }
                
                // Verifica duplicatas
                if (init.name in initializedFields)
                {
                    reportError(
                        format("Field '%s' initialized multiple times", init.name),
                        init.loc
                    );
                    continue;
                }
                initializedFields[init.name] = true;
                
                // Valida tipo
                Type fieldType = structType.getFieldType(init.name);
                Type valueType = checkExpression(init.value);
                
                if (!fieldType.isCompatibleWith(valueType))
                    reportError(
                        format("Field '%s': expected '%s', got '%s'",
                               init.name, fieldType.toStr(), valueType.toStr()),
                        init.value.loc
                    );
            }
            
            // Verifica se campos sem valor padrão foram inicializados
            foreach (field; structType.fields)
            {
                if (field.name !in initializedFields && field.defaultValue is null)
                    reportError(
                        format("Field '%s' must be initialized (no default value)", field.name),
                        lit.loc,
                        [Suggestion(format("Add: .%s = <value>", field.name))]
                    );
            }
        }

        return lit.resolvedType;
    }

    Type checkMemberExpr(MemberExpr expr)
    {
        void structError(StructType structType, string member, Loc loc)
        {
            reportError(
                    format("Struct '%s' does not have field '%s'",
                           structType.name, member),
                    loc,
                    [Suggestion(format("Available fields: %s", 
                        getAvailableFields(structType)))]
                );
        }

        void unionError(UnionType un, string member, Loc loc)
        {
            reportError(
                    format("Union '%s' does not have field '%s'",
                           un.name, member),
                    loc,
                    [Suggestion(format("Available fields: %s", 
                        getAvailableFields(un)))]
                );
        }

        void enumError(EnumType enm, string member, Loc loc)
        {
            reportError(
                    format("Enum '%s' does not have field '%s'",
                           enm.name, member),
                    loc,
                    [Suggestion(format("Available fields: %s", 
                        getAvailableFields(enm)))]
                );
        }

        Type targetType = checkExpression(expr.target);

        if (StructType structType = cast(StructType) targetType)
        {
            if (!structType.hasField(expr.member))
            {
                structError(structType, expr.member, expr.loc);
                return new PrimitiveType(BaseType.Any);
            }

            // Retorna o tipo do campo
            Type fieldType = structType.getFieldType(expr.member);
            expr.resolvedType = fieldType;
            return fieldType;
        }

        // 2. Acesso a campo através de ponteiro para struct
        if (PointerType ptrType = cast(PointerType) targetType)
        {
            if (StructType structType = cast(StructType) ptrType.pointeeType)
            {
                // ptr->field é equivalente a (*ptr).field
                if (!structType.hasField(expr.member))
                {
                    structError(structType, expr.member, expr.loc);
                    return new PrimitiveType(BaseType.Any);
                }
                Type fieldType = structType.getFieldType(expr.member);
                expr.resolvedType = fieldType;
                return fieldType;
            }
        }

        if (UnionType un = cast(UnionType) targetType)
        {
            // Verifica se o campo existe
            if (!un.hasField(expr.member))
            {
                unionError(un, expr.member, expr.loc);
                return new PrimitiveType(BaseType.Any);
            }

            // Retorna o tipo do campo
            Type fieldType = un.getFieldType(expr.member);
            expr.resolvedType = fieldType;
            return fieldType;
        }

        if (EnumType enm = cast(EnumType) targetType)
        {
            // Verifica se o campo existe
            if (!enm.hasMember(expr.member))
            {
                enumError(enm, expr.member, expr.loc);
                return new PrimitiveType(BaseType.Any);
            }

            // Retorna o tipo do campo
            Type fieldType = new PrimitiveType(BaseType.Int);
            expr.resolvedType = fieldType;
            return fieldType;
        }

        reportError(
            format("Type '%s' does not have members", targetType.toStr()),
            expr.target.loc,
            [Suggestion("Only structs and pointers to structs support member access")]
        );
        return new PrimitiveType(BaseType.Any);
    }

    string getAvailableFields(StructType structType)
    {
        if (structType.fields.length == 0)
            return "(none)";

        return structType.fields.map!(f => f.name).join(", ");
    }

    string getAvailableFields(UnionType un)
    {
        if (un.fields.length == 0)
            return "(none)";

        return un.fields.map!(f => f.name).join(", ");
    }    

    string getAvailableFields(EnumType enm)
    {
        if (enm.members.length == 0)
            return "(none)";

        return enm.members.byKey.map!(f => f).join(", ");
    }

    Type checkSizeof(SizeOfExpr sizeof)
    {
        Type type = new TypeResolver(ctx, error, registry).resolve(sizeof.type);
        if (sizeof.value !is null)
            sizeof.value.resolvedType = checkExpression(sizeof.value);
        sizeof.resolvedType_ = new TypeResolver(ctx, error, registry).resolve(sizeof.type_);
        sizeof.resolvedType = type;
        return type;
    }

    Type checkCastExpr(CastExpr expr)
    {
        expr.resolvedType = new TypeResolver(ctx, error, registry).resolve(expr.target);
        expr.from.resolvedType = checkExpression(expr.from);
        checkTypeComp(expr.resolvedType, expr.from.resolvedType, expr.loc, false);
        return expr.resolvedType;
    }

    Type checkTernary(TernaryExpr ternary)
    {
        Type condition = checkExpression(ternary.condition);
        Type left = ternary.trueExpr is null ? null : checkExpression(ternary.trueExpr);
        Type right = checkExpression(ternary.falseExpr);

        if (!checkType(condition, new PrimitiveType(BaseType.Bool), ternary.loc))
            return new PrimitiveType(BaseType.Any);

        if (left is null)
            return right;

        if (!checkTypeBoth(left, right, ternary.loc))
            return new PrimitiveType(BaseType.Any);

        if (right.toStr() == left.toStr())
            return left;

        return left;
    }

    Type checkIdentifier(ref Identifier ident)
    {
        string id = ident.value.get!string;
        Symbol sym = ctx.lookup(id);

        if (sym is null)
        {
            reportError(format("'%s' was not declared.", id), ident.loc);
            return new PrimitiveType(BaseType.Any);
        }

        if (FunctionSymbol fn = cast(FunctionSymbol) sym)
        {
            FunctionType type = new FunctionType(fn.paramTypes, fn.returnType);
            type.mangled = fn.declaration.mangledName;
            ident.resolvedType = type;
            ident.mangledName = type.mangled;
            ident.isFunctionReference = true;
            return type;
        }

        if (sym.type is null)
        {
            reportError(format("'%s' has no defined type.", id), ident.loc);
            return new PrimitiveType(BaseType.Any);
        }

        ident.resolvedType = sym.type;
        return sym.type;
    }

    bool isInteger(Type t)
    {
        if (PrimitiveType primi = cast(PrimitiveType) t)
            return primi.baseType == BaseType.Int || primi.baseType == BaseType.Long;
        return false;
    }

    Type checkBinaryExpr(BinaryExpr expr, Node n)
    {
        Type leftType = checkExpression(expr.left);
        expr.left.resolvedType = leftType;
        Type rightType = checkExpression(expr.right);
        expr.right.resolvedType = rightType;
        PointerType ptr;
        
        string op = expr.op;

        // Caso 1: Ponteiro + Inteiro (ex: walker + 1)
        if (op == "+" && leftType.isPointer() && isInteger(rightType))
        {
            ptr = cast(PointerType) leftType;
            if (ptr.isCompatibleWith(rightType, false))
            {
                expr.resolvedType = leftType; // O resultado continua sendo User*
                return expr.resolvedType;
            }
        }

        // Caso 2: Ponteiro - Inteiro (ex: walker - 2)
        if (op == "-" && leftType.isPointer() && isInteger(rightType))
        {
            ptr = cast(PointerType) leftType;
            if (ptr.isCompatibleWith(rightType, false))
            {
                expr.resolvedType = leftType; // O resultado continua sendo User*
                return expr.resolvedType;
            }
        }

        string getOpName(string op, bool isRight)
        {
            if (isRight)
                switch (op)
                    {
                    case "+":  return "opAddRight";
                    case "-":  return "opSubRight";
                    case "*":  return "opMulRight";
                    case "/":  return "opDivRight";
                    case "%":  return "opModRight";
                    case "==": return "opEqualsRight";
                    case "!=": return "opNotEqualsRight";
                    case "<":  return "opLessRight";
                    case ">":  return "opGreaterRight";
                    case "<=": return "opLessEqualRight";
                    case ">=": return "opGreaterEqualRight";
                    default: return null; 
                }
            else
                switch (op)
                {
                    case "+":  return "opAdd";
                    case "-":  return "opSub";
                    case "*":  return "opMul";
                    case "/":  return "opDiv";
                    case "%":  return "opMod";
                    case "==": return "opEquals";
                    case "!=": return "opNotEquals";
                    case "<":  return "opLess";
                    case ">":  return "opGreater";
                    case "<=": return "opLessEqual";
                    case ">=": return "opGreaterEqual";
                    default: return null;
                }
        }

        Type tryResolveOperator(StructType st, string op, Type inputType, BinaryExpr expr, bool isRight)
        {
            string methodName = getOpName(op, isRight);
            StructMethod* method = null;

            if (methodName !is null && st.hasMethod(methodName))
            {
                method = st.findMethod(methodName, [inputType]);
                if (method !is null)
                {
                    expr.mangledName = method.funcDecl.mangledName;
                    expr.resolvedType = method.funcDecl.resolvedType;
                    if (isRight) expr.isRight = true; // Seta flag se necessário
                    return expr.resolvedType;
                }
            }
        
            if (st.hasMethod("opBinary"))
            {
                method = st.findMethod("opBinary", [new PointerType(new PrimitiveType(BaseType.Char)), inputType]);
                if (method !is null)
                {
                    expr.mangledName = method.funcDecl.mangledName;
                    expr.resolvedType = method.funcDecl.resolvedType;
                    expr.usesOpBinary = true;
                    if (isRight) expr.isRight = true;
                    return expr.resolvedType;
                }
            }

            return null;
        }

        if (auto st = cast(StructType) leftType)
        {
            Type result = tryResolveOperator(st, op, rightType, expr, false); // isRight = false
            if (result !is null) return result;

            reportError(format("Struct '%s' does not implement operator '%s' for type '%s'", 
                st.name, op, rightType.toStr()), expr.loc);
            return new PrimitiveType(BaseType.Any);
        }

        if (auto st = cast(StructType) rightType)
        {
            Type result = tryResolveOperator(st, op, leftType, expr, true); // isRight = true
            if (result !is null) return result;

            reportError(format("Struct '%s' does not implement operator '%s' for type '%s'", 
                st.name, op, leftType.toStr()), expr.loc);
            return new PrimitiveType(BaseType.Any);
        }

        // Operadores aritméticos: +, -, *, /, %
        if (op == "+" || op == "-" || op == "*" || op == "/" || op == "%")
        {
            if (!leftType.isNumeric() || !rightType.isNumeric())
            {
                reportError(format("The '%s' operator requires numeric operands.", op), expr.loc);
                return new PrimitiveType(BaseType.Any);
            }

            // Type promotion
            Type t = leftType.getPromotedType(rightType);
            expr.resolvedType = t;
            makeImplicitCast(expr.right, expr.resolvedType);
            makeImplicitCast(expr.left, expr.resolvedType);
            return t;
        }

        // Operadores de comparação: ==, !=, <, >, <=, >=
        if (op == "==" || op == "!=" || op == "<" || op == ">" ||
            op == "<=" || op == ">=")
        {
            checkType(leftType, rightType, expr.loc);
            Type t = new PrimitiveType(BaseType.Bool);
            expr.resolvedType = t;
            return t;
        }

        // Operadores lógicos: &&, ||
        if (op == "&&" || op == "||")
        {
            auto boolType = new PrimitiveType(BaseType.Bool);
            checkTypeBoth(leftType, boolType, expr.loc);
            expr.resolvedType = boolType;
            return boolType;
        }

        // Operadores bitwise: &, |, ^, <<, >>, >>>
        if (op == "&" || op == "|" || op == "^" ||
            op == "<<" || op == ">>" || op == ">>>")
        {
            if (!leftType.isNumeric() || !rightType.isNumeric())
                reportError(format("The bitwise operator '%s' requires integer operands.", op), expr.loc);
            expr.resolvedType = leftType;
            return leftType;
        }

        reportError(format("Unknown binary operator: '%s'", op), expr.loc);
        return new PrimitiveType(BaseType.Any);
    }

    Type checkUnaryExpr(UnaryExpr expr)
    {
        Type operandType = checkExpression(expr.operand);
        string op = expr.op;
        expr.resolvedType = operandType;

        // Negação: -x
        if (op == "-")
        {
            if (!operandType.isNumeric())
                reportError("The operator '-' requires a numeric operand.", expr.loc);
            return operandType;
        }

        // NOT lógico: !x
        if (op == "!")
        {
            auto boolType = new PrimitiveType(BaseType.Bool);
            if (!operandType.isCompatibleWith(boolType))
                reportError("The '!' operator requires a logical operand.", expr.loc);
            expr.resolvedType = boolType;
            return boolType;
        }

        // NOT bitwise: ~x
        if (op == "~")
        {
            if (!operandType.isNumeric())
                reportError("The '~' operator requires an integer operand.", expr.loc);
            return operandType;
        }

        // ++, --
        if (op == "++" || op == "--" ||
            op == "++_prefix" || op == "--_prefix" ||
            op == "++_postfix" || op == "--_postfix")
        {
            if (!operandType.isNumeric())
                reportError(format("The '%s' operator requires a numeric operand.",
                        op[0 .. 2]), expr.loc);
            return operandType;
        }

        if (op == "&")
        {
            expr.resolvedType = new PointerType(operandType);
            return expr.resolvedType;
        }

        if (op == "*")
        {
            if (!operandType.isPointer())
            {
                reportError("The '*' operator requires a pointer.", expr.loc);
                return operandType;
            }
            expr.resolvedType = (cast(PointerType) operandType).pointeeType;
            return (cast(PointerType) operandType).pointeeType;
        }

        return operandType;
    }

    Type checkAssignDecl(AssignDecl expr)
    {
        Type targetType = checkExpression(expr.left);
        Type valueType = checkExpression(expr.right);
            
        // Verifica se pode atribuir
        if (auto ident = cast(Identifier) expr.left)
        {
            string id = ident.value.get!string;
            if (!ctx.canAssign(id))
                reportError(format("'%s' is a constant and cannot be modified.", id), expr.loc);
        }

        // Atribuição simples: =
        if (expr.op == "=")
        {
            if (!valueType.isCompatibleWith(targetType))
                reportError(format("Incompatible type: cannot assign '%s' to '%s'.",
                        valueType.toStr(), targetType.toStr()), expr.loc);
            return targetType;
        }

        // Atribuições compostas: +=, -=, *=, etc
        // Checa como operação binária
        string binOp = expr.op[0 .. $ - 1]; // remove '='
        auto binaryType = checkBinaryExpr(
            new BinaryExpr(expr.left, expr.right, binOp, expr.loc), null
        );

        if (!binaryType.isCompatibleWith(targetType))
            reportError(format("Incompatible type in compound assignment '%s'.", expr.op), expr.loc);
    
        return targetType;
    }

    Type checkCallExpr(CallExpr expr)
    {
        if (expr.isTemplate || expr.templateType.length > 0)
        {
            string id = "";
            if (auto ident = cast(Identifier) expr.id) id = ident.value.get!string;
            else {
                reportError("Template call must be on an identifier.", expr.loc);
                return new PrimitiveType(BaseType.Any);
            }

            Symbol sym = ctx.lookup(id);
            if (!sym || !sym.isTemplate) {
                reportError(format("Template function '%s' not found.", id), expr.loc);
                return new PrimitiveType(BaseType.Any);
            }

            // === DELEGAÇÃO PARA O NOVO ARQUIVO ===
            auto instantiator = new TemplateInstantiator(ctx, error, registry, this);
            FunctionSymbol concreteSym = instantiator.instantiate(expr, cast(FunctionSymbol) sym);
            
            if (!concreteSym) return new PrimitiveType(BaseType.Any);

            // Redireciona a chamada para a função concreta criada
            if (auto ident = cast(Identifier) expr.id) {
                ident.value = concreteSym.name; // "cast" vira "cast_int_double"
                ident.resolvedType = null;
            }
            expr.isTemplate = false;
            expr.templateType = [];
        }

        // Caso 1: Chamada de Método (obj.metodo())
        if (MemberExpr mem = cast(MemberExpr) expr.id)
        {                            
            Type targetType = checkExpression(mem.target);

            // Se for ponteiro, pega a struct apontada
            StructType structType;
            if (auto pt = cast(PointerType) targetType)
                structType = cast(StructType) pt.pointeeType;
            else
                structType = cast(StructType) targetType;

            if (structType is null) {
                reportError("Methods can only be called on Structs or Pointers to Structs.", mem.loc);
                return new PrimitiveType(BaseType.Any);
            }

            Type[] argTypes;
            foreach (arg; expr.args)
                argTypes ~= checkExpression(arg);
            
            StructMethod* method = structType.findMethod(mem.member, argTypes);
            if (method is null) {
                reportError(format("The method '%s' does not exist in the struct '%s' with the given signature.", 
                    mem.member, structType.name), mem.loc);
                return new PrimitiveType(BaseType.Any);
            }

            FuncDecl funcDecl = method.funcDecl;
            size_t expectedArgs = funcDecl.args.length;
            size_t providedArgs = expr.args.length + 1; // +1 do 'this' implícito

            if (providedArgs != expectedArgs)
                 reportError(format("The method expects %d arguments (including self), but received %d.", expectedArgs, 
                    providedArgs), expr.loc);

            // Valida o 'self' (primeiro parametro)
            Type thisParamType = funcDecl.args[0].resolvedType;
            // Determina o tipo que será passado
            Type passedType = targetType;
            // Se o alvo é um VALOR (Struct), o compilador vai passar o endereço implicitamente (&u)
            if (targetType.isStruct())
                passedType = new PointerType(targetType);

            if (!thisParamType.isCompatibleWith(passedType))
                 reportError(format("Error in 'self': Method expects '%s', but the object is '%s'", 
                    thisParamType.toStr(), targetType.toStr()), mem.loc);

            // Valida o resto dos argumentos (já foram coletados em argTypes)
            foreach (i, argType; argTypes) {
                if (i + 1 >= funcDecl.args.length) {
                    // Não podemos checar 'funcDecl.args[$-1] is null' se for struct.
                    // Checamos se o NOME do último argumento é "..." ou se o TIPO dele é null.
                    bool isVariadic = false;

                    if (funcDecl.args.length > 0) {
                        auto lastArg = funcDecl.args[$-1];
                        // Verifica se é variadic pelo nome "..." ou se o resolvedType é nulo
                        if (lastArg.name == "..." || lastArg.resolvedType is null)
                            isVariadic = true;
                    }

                    if (!isVariadic) {
                        reportError(
                        format("Too many arguments for the '%s' method. Expected %d, but received %d (including self).", 
                            method.funcDecl.name, funcDecl.args.length, expr.args.length + 1), 
                            expr.args[i].loc
                        );
                        break;
                    } else
                        // Se é variadic, aceita argumentos extras
                        continue; 
                }

                // offset +1 nos parametros da função (pula o this)
                Type paramType = funcDecl.args[i+1].resolvedType;
                bool result = paramType.isPointer() ? (cast(PointerType)paramType).isCompatibleWith(argType, true)
                     : paramType.isCompatibleWith(argType);

                // writeln("CALL: ", funcDecl.name, " -> ", paramType.toStr(), " | ", argType.toStr());

                if (!result)
                     reportError(
                        format("Incompatible argument #%d: expected '%s', received '%s'", 
                        i + 1, paramType.toStr(), argType.toStr()), 
                        expr.args[i].loc
                    );
            }

            expr.resolvedType = funcDecl.resolvedType;
            expr.mangledName = funcDecl.mangledName;
            return funcDecl.resolvedType;
        }

        Type[] argTypes;
        foreach (arg; expr.args)
            argTypes ~= checkExpression(arg);

        FunctionSymbol funcSym = null;
        Symbol sym = null;
        bool isRef = false;
        FunctionType type;
        Node ident = null;
        string id = "";

        if (Identifier id_ = cast(Identifier) expr.id)
            ident = id_;

        if (StringLit str = cast(StringLit) expr.id)
            ident = str;

        if (ident !is null)
        {
            id = ident.value.get!string;
            funcSym = ctx.findFunction(id, argTypes, null);

            if (funcSym is null)
            {
                sym = ctx.lookup(id);
                if (sym !is null)
                {
                    if (FunctionType t = cast(FunctionType) sym.type)
                    {
                        type = t;
                        if (t.mangled != "")
                            expr.mangledName = t.mangled;
                        else
                            expr.mangledName = id;
                        funcSym = new FunctionSymbol(id, t.paramTypes, t.returnType, null, ident.loc);
                        isRef = true;
                        expr.isRef = true;
                        expr.refType = t;
                    }
                }
            }
        }

        if (funcSym is null)
        {
            reportError("Attempting to call something that is not a function.", expr.loc);
            return new PrimitiveType(BaseType.Any);
        }

        // Verifica se a função tem parâmetros variádicos
        bool hasVariadic = false;
        size_t minArgs = funcSym.paramTypes.length;

        foreach (i, param; funcSym.paramTypes)
            if (param is null) {
                hasVariadic = true;
                minArgs = i; // Argumentos obrigatórios antes do variádico
                break;
            }

        // Verifica número mínimo de argumentos
        if (hasVariadic)
        {
            if (expr.args.length < minArgs)
            {
                reportError(format("The function expects at least %d arguments, and has received %d.",
                        minArgs, expr.args.length), expr.loc);
                return funcSym.returnType;
            }
        }
        else
        {
            // Função sem variadics: número exato
            if (expr.args.length != funcSym.paramTypes.length)
            {
                reportError(format("The function expects %d arguments, it got %d.",
                        funcSym.paramTypes.length, expr.args.length), expr.loc);
                return funcSym.returnType;
            }
        }

        expr.isVarArg = hasVariadic;
        if (funcSym.declaration !is null)
            expr.isVarArgAt = funcSym.declaration.isVarArgAt;
        expr.isExternalCall = funcSym.isExternal;

        // Verifica tipo dos argumentos até encontrar variádico
        // Agora usa argTypes ao invés de chamar checkExpression novamente
        foreach (i, argType; argTypes)
        {
            // Só checa tipos dos argumentos antes do variádico
            if (i < minArgs)
            {
                Type paramType = funcSym.paramTypes[i];
                if (!paramType.isCompatibleWith(argType))
                    reportError(format("Argument %d: expected '%s', got '%s'.",
                            i + 1, paramType.toStr(), argType.toStr()), expr.args[i].loc);
            }
            // Argumentos depois do variádico: aceita qualquer tipo
        }

        if (isRef)
        {
            expr.resolvedType = type.returnType;
            return type.returnType;
        }
        else {
            expr.mangledName = funcSym.declaration.mangledName;
            expr.resolvedType = funcSym.returnType;
            return funcSym.returnType;
        }
    }

    Type checkIndexExpr(IndexExpr expr)
    {
        Type targetType = checkExpression(expr.target);
        Type indexType = checkExpression(expr.index);

        // Índice deve ser inteiro
        if (!new PrimitiveType(BaseType.Int).isCompatibleWith(indexType))
            reportError(format("The index must be an integer; it was obtained as '%s'.",
                    indexType.toStr()), expr.index.loc);
        
        if (auto arrType = cast(ArrayType) targetType)
        {
            expr.resolvedType = arrType.elementType;
            return arrType.elementType;
        }

        if (auto ptrType = cast(PointerType) targetType)
        {
            expr.resolvedType = ptrType.pointeeType;
            return ptrType.pointeeType;
        }

        if (PrimitiveType primitive = cast(PrimitiveType) targetType)
        {
            if (primitive.baseType == BaseType.String) {
                expr.resolvedType = new PrimitiveType(BaseType.Char);
                return new PrimitiveType(BaseType.Char);
            }
        }

        if (StructType st = cast(StructType) targetType)
        {
            if (st.hasMethod("opIndex"))
            {
                StructMethod* method = st.getMethod("opIndex");
                expr.mangledName = method.funcDecl.mangledName;
                return method.funcDecl.resolvedType;
            }
        }

        reportError(format("'%s' is not indexable.", targetType.toStr()), expr.target.loc);
        return new PrimitiveType(BaseType.Any);
    }

    Type checkArrayLiteral(ArrayLit expr)
    {
        if (expr.elements.length == 0)
            // Array vazio - tipo genérico
            return new ArrayType(new PrimitiveType(BaseType.Any));
        
        // Infere tipo do primeiro elemento
        Type elemType = checkExpression(expr.elements[0]);

        // Verifica que todos elementos são compatíveis
        foreach (i, elem; expr.elements[1 .. $])
        {
            Type thisType = checkExpression(elem);
            if (!thisType.isCompatibleWith(elemType))
                reportError(format(
                        "Element %d of the array has an incompatible type: expected '%s', got '%s'",
                        i + 2, elemType.toStr(), thisType.toStr()), elem.loc);
        }

        Type t = new ArrayType(elemType);
        expr.resolvedType = t;
        return t;
    }
}
