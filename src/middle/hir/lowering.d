module middle.hir.lowering;

import frontend.parser.ast;
import middle.hir.hir;
import frontend.types.type;
import std.conv : to;
import std.stdio : writeln;

class AstLowerer {
    int[string] structOffsets;  // Cache de offsets: "StructName.field" -> offset
    int[string] structSizes;    // Cache de tamanhos: "StructName" -> size
    int[string] structAlignments;

    HirProgram lower(Program ast)
    {
        auto hir = new HirProgram();

        // Primeiro pass: registra structs e calcula layouts
        foreach (node; ast.body)
            if (node.kind == NodeKind.StructDecl) {
                StructDecl sd = cast(StructDecl)node;
                if (!sd.isTemplate)
                    calculateStructLayout(sd);
            }
            else if (node.kind == NodeKind.UnionDecl)
                calculateUnionLayout(cast(UnionDecl)node);

        foreach (node; ast.body) {
            if (node.kind == NodeKind.FuncDecl) {
                FuncDecl fn = cast(FuncDecl) node;
                if (fn.isTemplate)
                    continue;
                hir.globals ~= lowerFunc(fn);
            }
            else if (node.kind == NodeKind.VersionStmt)
                hir.globals ~= lowerVersion(cast(VersionStmt) node);
            else if (node.kind == NodeKind.VarDecl)
                hir.globals ~= lowerVarDecl(cast(VarDecl) node);
            else if (node.kind == NodeKind.VersionStmt)
                lowerVersion(cast(VersionStmt) node);
            else if (node.kind == NodeKind.StructDecl) {
                StructDecl sd = cast(StructDecl) node;
                if (sd.isTemplate)
                    continue;
                hir.globals ~= lowerStructDecl(sd);
                foreach (methodName, overloads; sd.methods)
                    foreach (method; overloads) 
                    {
                        // Mangle: Muda o nome de "print" para "User_print"
                        string originalName = method.funcDecl.name;
                        method.funcDecl.name = method.funcDecl.mangledName;
                        hir.globals ~= lowerFunc(method.funcDecl);
                        // method.funcDecl.name = originalName;
                    }
            } else if (node.kind == NodeKind.UnionDecl)
                hir.globals ~= lowerUnionDecl(cast(UnionDecl) node);
            else if (node.kind == NodeKind.EnumDecl)
                hir.globals ~= lowerEnumDecl(cast(EnumDecl) node);
        }
        return hir;
    }

private:

    HirNode lowerSwitch(SwitchStmt ast)
    {
        auto hirSwitch = new HirSwitch();
        hirSwitch.condition = lowerExpr(ast.condition);

        foreach (caseStmt; ast.cases)
        {
            auto hirCase = new HirCaseStmt();
            hirCase.isDefault = caseStmt.isDefault;

            // Lowering dos valores do case
            foreach (value; caseStmt.values)
                hirCase.values ~= lowerExpr(value);

            // Lowering do corpo
            hirCase.body = lowerBlock(caseStmt.body);

            hirSwitch.cases ~= hirCase;
        }

        return hirSwitch;
    }

    HirNode lowerForEach(ForEachStmt ast)
    {
        auto block = new HirBlock();

        Type iterableType = ast.iterable.resolvedType;
        StructType collectionStruct = cast(StructType) iterableType;

        if (collectionStruct is null)
            if (PointerType ptrType = cast(PointerType) iterableType)
                collectionStruct = cast(StructType) ptrType.pointeeType;

        if (collectionStruct is null) return block; 

        StructMethod* methodOpIter = collectionStruct.getMethod("opIter");
        if (methodOpIter is null) {
            writeln("Erro: opIter não encontrado em ", collectionStruct.name);
            return block;
        }

        Type iteratorType = methodOpIter.funcDecl.resolvedType;
        StructType iteratorStruct = cast(StructType) iteratorType;
        
        if (iteratorStruct is null)
            if (PointerType ptr = cast(PointerType) iteratorType)
                iteratorStruct = cast(StructType) ptr.pointeeType;

        string iterVarName = "__iter_" ~ to!string(cast(void*)ast);
        auto iterVarDecl = new HirVarDecl();
        iterVarDecl.name = iterVarName;
        iterVarDecl.type = iteratorType; // Tipo correto: O Iterador, não a coleção
        iterVarDecl.isGlobal = false;

        auto opIterCall = new HirCallExpr();
        opIterCall.funcName = methodOpIter.funcDecl.mangledName; 
        opIterCall.type = iteratorType;
        opIterCall.args ~= lowerLValue(ast.iterable); // Passa o 'self' da coleção
        
        iterVarDecl.initValue = opIterCall;
        block.stmts ~= iterVarDecl;

        StructMethod* methodOpNext = iteratorStruct.getMethod("opNext");
        if (methodOpNext is null) {
            writeln("Erro: opNext não encontrado no iterador ", iteratorStruct.name);
            return block;
        }

        Type valueType = methodOpNext.funcDecl.resolvedType;
        string valVarName = "__val_" ~ to!string(cast(void*)ast);
        auto valVarDecl = new HirVarDecl();
        valVarDecl.name = valVarName;
        valVarDecl.type = valueType;
        valVarDecl.isGlobal = false;
        valVarDecl.initValue = getDefaultValue(valueType); // Inicializa com null/zero
        block.stmts ~= valVarDecl;

        auto whileStmt = new HirWhile();

        // Condição: (__val = __iter.opNext()) != null        
        // Chamada __iter.opNext()
        auto opNextCall = new HirCallExpr();
        opNextCall.funcName = methodOpNext.funcDecl.mangledName;
        opNextCall.type = valueType;

        if (cast(PointerType) iteratorType) 
        {
            auto iterLoad = new HirLoad();
            iterLoad.varName = iterVarName;
            iterLoad.type = iteratorType;
            opNextCall.args ~= iterLoad;
        }
        else 
        {
            auto iterAddr = new HirAddrOf();
            iterAddr.varName = iterVarName;
            iterAddr.type = iteratorType; 
            opNextCall.args ~= iterAddr;
        }

        auto valAssign = new HirAssignDecl();
        valAssign.op = "=";
        
        auto valAddr = new HirAddrOf();
        valAddr.varName = valVarName;
        valAddr.type = valueType;
        
        valAssign.target = valAddr;
        valAssign.value = opNextCall;

        auto assignExpr = new HirAssignExpr();
        assignExpr.assign = valAssign;
        assignExpr.type = valueType;

        // Comparação: ... != null
        auto condition = new HirBinary();
        condition.op = "!=";
        condition.left = assignExpr;
        condition.right = new HirNullLit(valueType);
        condition.type = new PrimitiveType(BaseType.Bool);

        whileStmt.condition = condition;
        auto whileBody = new HirBlock();

        auto userVarDecl = new HirVarDecl();
        userVarDecl.name = ast.iterVar;
        userVarDecl.type = valueType; 
        userVarDecl.isGlobal = false;

        auto valLoad = new HirLoad();
        valLoad.varName = valVarName;
        valLoad.type = valueType;
        
        userVarDecl.initValue = valLoad;
        whileBody.stmts ~= userVarDecl;

        foreach (stmt; ast.body.statements)
        {
            auto lowered = lowerStmt(stmt);
            if (lowered !is null)
                whileBody.stmts ~= lowered;
        }

        whileStmt.body = whileBody;
        block.stmts ~= whileStmt;

        return block;
    }

    HirNode lowerUnionDecl(UnionDecl ast)
    {
        auto decl = new HirUnionDecl();
        decl.name = ast.mangledName;
        decl.type = ast.resolvedType; 

        foreach (field; ast.fields)
        {
            decl.fieldNames ~= field.name;
            decl.fieldTypes ~= field.resolvedType;
            string key = ast.name ~ "." ~ field.name;
            decl.fieldOffsets ~= structOffsets.get(key, 0);
        }

        decl.totalSize = structSizes.get(ast.mangledName, 0);
        return decl;
    }

    HirNode lowerEnumDecl(EnumDecl ast)
    {
        // Enum no backend é só inteiro, mas podemos guardar metadados se quiser
        auto decl = new HirEnumDecl();
        decl.name = ast.name;
        decl.type = ast.resolvedType; 
        // Campos/Membros do enum
        return decl;
    }

    void calculateUnionLayout(UnionDecl ast)
    {
        int maxSize = 0;
        int unionMaxAlign = 1;

        foreach (field; ast.fields) {
            int fieldAlign = getTypeAlignment(field.resolvedType);
            int fieldSize = cast(int) calculateTypeSize(field.resolvedType);

            if (fieldAlign > unionMaxAlign) unionMaxAlign = fieldAlign;
            if (fieldSize > maxSize) maxSize = fieldSize;

            // Offset é sempre 0
            string key = ast.mangledName ~ "." ~ field.name;
            structOffsets[key] = 0; 
        }

        // Padding final para alinhamento
        if (maxSize % unionMaxAlign != 0) {
            int padding = unionMaxAlign - (maxSize % unionMaxAlign);
            maxSize += padding;
        }
        
        if (maxSize == 0) maxSize = 1;

        structSizes[ast.mangledName] = maxSize;
        structAlignments[ast.mangledName] = unionMaxAlign;
    }

    void calculateStructLayout(StructDecl ast)
    {
        int currentOffset = 0;
        int structMaxAlign = 1; // O alinhamento da struct começa em 1 (mínimo)
        
        StructType structType = cast(StructType) ast.resolvedType;
        if (structType is null) return;
        
        foreach (field; structType.fields) {
            // 1. Descobre o alinhamento necessário para este campo
            int fieldAlign = getTypeAlignment(field.resolvedType);
            int fieldSize = cast(int) calculateTypeSize(field.resolvedType);
            
            // 2. O alinhamento da struct será o maior alinhamento entre seus campos
            if (fieldAlign > structMaxAlign) {
                structMaxAlign = fieldAlign;
            }
            
            // 3. Aplica Padding antes do campo (se necessário)
            if (currentOffset % fieldAlign != 0) {
                int padding = fieldAlign - (currentOffset % fieldAlign);
                currentOffset += padding;
            }
            
            // Armazena o offset deste campo
            string key = ast.mangledName ~ "." ~ field.name;
            structOffsets[key] = currentOffset;
            
            // Avança o offset
            currentOffset += fieldSize;
        }
        
        // 4. Padding Final: O tamanho total da struct deve ser múltiplo do seu alinhamento
        if (currentOffset % structMaxAlign != 0) {
            int padding = structMaxAlign - (currentOffset % structMaxAlign);
            currentOffset += padding;
        }
        
        // Caso de struct vazia (em C é proibido ter tamanho 0, geralmente vira 1)
        if (currentOffset == 0) currentOffset = 1;
        
        structSizes[ast.mangledName] = currentOffset;
        structAlignments[ast.mangledName] = structMaxAlign; // Salva para uso futuro
    }
    
    int getTypeAlignment(Type t)
    {
        if (auto prim = cast(PrimitiveType) t)
        {
            switch(prim.baseType)
            {
                case BaseType.Bool:
                case BaseType.Char:
                    return 1;
                case BaseType.Int:
                case BaseType.Float:
                    return 4; // Ints e Floats alinham em 4 bytes
                case BaseType.Long:
                case BaseType.Double:
                case BaseType.String: // String é um ponteiro (ou struct slice)
                    return 8; // 64-bit systems alinham ponteiros/longs em 8
                default:
                    return 1;
            }
        }
        if (cast(PointerType) t) return 8; // Ponteiros alinham em 8
        if (ArrayType arr = cast(ArrayType) t)
            return getTypeAlignment(arr.elementType);
        
        // Se for uma struct, o alinhamento dela é o maior alinhamento de seus campos
        if (auto st = cast(StructType) t)
        {
            if (st.name in structAlignments)
                return structAlignments[st.name];
            // Fallback se ainda não calculou (cuidado com ordem de declaração)
            return 1; 
        }

        if (UnionType ut = cast(UnionType) t) 
        {
            int maxA = 1;
            foreach(StructField field; ut.fields) {
                int a = getTypeAlignment(field.resolvedType);
                if (a > maxA) maxA = a;
            }
            return maxA;
        }
        
        return 1;
    }
    
    HirNode lowerStructDecl(StructDecl ast)
    {
        auto decl = new HirStructDecl();
        decl.name = ast.mangledName;
        
        StructType structType = cast(StructType) ast.resolvedType;
        if (structType is null) return decl;
        
        // Coleta informações dos campos
        foreach (field; structType.fields)
        {
            decl.fieldNames ~= field.name;
            decl.fieldTypes ~= field.resolvedType;
            
            string key = ast.mangledName ~ "." ~ field.name;
            decl.fieldOffsets ~= structOffsets.get(key, 0);
        }
        
        decl.totalSize = structSizes.get(ast.name, 0);
        decl.type = structType;
        
        return decl;
    }
    
    HirNode lowerStructLit(StructLit ast)
    {
        auto lit = new HirStructLit();
        lit.structName = ast.mangledName;
        lit.type = ast.resolvedType;
        lit.isConstructorCall = ast.isConstructorCall;
        
        StructType structType = cast(StructType) ast.resolvedType;
        if (structType is null) return lit;
        
        // Cria array de valores na ordem dos campos da struct
        HirNode[] orderedValues = new HirNode[structType.fields.length];
        
        if (ast.isPositional || ast.isConstructorCall)
        {
            // Inicialização posicional ou construtor: valores já estão na ordem
            foreach (i, init; ast.fieldInits)
                if (i < orderedValues.length)
                    orderedValues[i] = lowerExpr(init.value);
        }
        else {
            // Inicialização nomeada: precisa mapear nomes para posições
            foreach (init; ast.fieldInits)
                // Encontra o índice do campo
                foreach (i, field; structType.fields)
                    if (field.name == init.name) {
                        orderedValues[i] = lowerExpr(init.value);
                        break;
                    }
        }
        
        // Preenche campos não inicializados com valores padrão
        foreach (i, field; structType.fields)
            if (orderedValues[i] is null)
            {
                if (field.defaultValue !is null) // Usa valor padrão do campo
                    orderedValues[i] = lowerExpr(field.defaultValue);
                else
                    // Usa zero/null
                    orderedValues[i] = getDefaultValue(field.resolvedType);
            }
        
        lit.fieldValues = orderedValues;
        return lit;
    }
    
    // Gera valor padrão para um tipo (zero/null)
    HirNode getDefaultValue(Type t)
    {
        if (auto prim = cast(PrimitiveType) t)
        {
            switch(prim.baseType)
            {
                case BaseType.Bool:
                    return new HirBoolLit(false, t);
                case BaseType.Char:
                    return new HirCharLit('\0', t);
                case BaseType.Int:
                case BaseType.Long:
                    return new HirIntLit(0, t);
                case BaseType.Float:
                case BaseType.Double:
                    return new HirFloatLit(0.0, t);
                case BaseType.String:
                    return new HirStringLit("", t);
                default:
                    return new HirNullLit(t);
            }
        }
        if (cast(PointerType) t)
            return new HirNullLit(t);
        return new HirNullLit(t);
    }
    
    // Lower member expression (melhorado)
    HirNode lowerMember(MemberExpr ast)
    {
        auto mem = new HirMemberAccess();
        mem.target = lowerExpr(ast.target);
        mem.memberName = ast.member;
        mem.type = ast.resolvedType;
        
        // Calcula offset do membro
        Type targetType = ast.target.resolvedType;
        
        // Se for ponteiro, pega o tipo apontado
        if (auto ptrType = cast(PointerType) targetType)
            targetType = ptrType.pointeeType;
        
        if (auto structType = cast(StructType) targetType) {
            string key = structType.mangledName ~ "." ~ ast.member;
            mem.memberOffset = structOffsets.get(key, 0);
        } else
            mem.memberOffset = 0;
        
        return mem;
    }

    HirVersion lowerVersion(VersionStmt ast)
    {
        return new HirVersion(lowerBlock(ast.resolvedBranch));
    }

    HirFunction lowerFunc(FuncDecl ast)
    {
        auto func = new HirFunction();            
        func.name = ast.mangledName;
        func.returnType = ast.resolvedType;
        
        foreach(arg; ast.args)
        {
            func.argNames ~= arg.name;
            func.argTypes ~= arg.resolvedType;
        }

        if (ast.body !is null)
            func.body = lowerBlock(ast.body);

        func.isVarArg = ast.isVarArg;
        func.isVarArgAt = ast.isVarArgAt;
        return func;
    }

    HirBlock lowerBlock(BlockStmt ast)
    {
        auto block = new HirBlock();
        foreach (stmt; ast.statements) {
            auto lowered = lowerStmt(stmt);
            if (lowered !is null) block.stmts ~= lowered;
        }
        return block;
    }

    HirNode lowerStmt(Node node)
    {
        if (node is null) return null;

        switch (node.kind)
        {
            case NodeKind.VarDecl:      return lowerVarDecl(cast(VarDecl) node);
            case NodeKind.FuncDecl:     return lowerFunc(cast(FuncDecl) node);
            case NodeKind.ReturnStmt:   return lowerReturn(cast(ReturnStmt) node);
            case NodeKind.IfStmt:       return lowerIf(cast(IfStmt) node);
            case NodeKind.ForStmt:      return lowerFor(cast(ForStmt) node);
            case NodeKind.ForEachStmt:  return lowerForEach(cast(ForEachStmt) node);
            case NodeKind.WhileStmt:    return lowerWhile(cast(WhileStmt) node);
            case NodeKind.AssignDecl:   return lowerAssign(cast(AssignDecl) node);
            case NodeKind.BlockStmt:    return lowerBlock(cast(BlockStmt) node);
            case NodeKind.VersionStmt:  return lowerVersion(cast(VersionStmt) node);
            case NodeKind.BrkOrCntStmt: return lowerBrkC(cast(BrkOrCntStmt) node);
            case NodeKind.CastExpr:     return lowerCast(cast(CastExpr) node);
            
            case NodeKind.CallExpr: 
                auto wrapper = new HirCallStmt();
                wrapper.call = cast(HirCallExpr) lowerExpr(node);
                return wrapper;
            
            case NodeKind.UnaryExpr:
                return lowerExpr(node);

            case NodeKind.DeferStmt:
                return lowerDefer(cast(DeferStmt) node);

            case NodeKind.SwitchStmt:
                return lowerSwitch(cast(SwitchStmt) node);

            default:
                writeln("Stmt nao implementado no HIR Lowering: ", node.kind);
                return null;
        }
    }

    HirNode lowerDefer(DeferStmt ast)
    {
        return new HirDefer(lowerStmt(ast.stmt));
    }

    HirNode lowerBrkC(BrkOrCntStmt node)
    {
        if (node.isBreak)
            return new HirBreak();
        return new HirContinue();
    }

    HirNode lowerVarDecl(VarDecl ast)
    {
        auto decl = new HirVarDecl();
        decl.name = ast.id;
        decl.type = ast.resolvedType;
        decl.isGlobal = ast.isGlobal;
        
        if (ast.value.get!Node !is null)
            decl.initValue = lowerExpr(ast.value.get!Node);

        return decl;
    }

    HirNode lowerReturn(ReturnStmt ast)
    {
        auto ret = new HirReturn();
        if (ast.value !is null)
            ret.value = lowerExpr(ast.value);
        return ret;
    }

    HirNode lowerIf(IfStmt ast)
    {
        auto stmt = new HirIf();

        // condições pra ser um else
        // se ast.condition is null então é um else
        // o else tem por padrão o bloco then

        if (ast.condition !is null)
            stmt.condition = lowerExpr(ast.condition);
        else
            stmt.condition = null; // Else standalone

        stmt.thenBlock = lowerBlock(cast(BlockStmt) ast.thenBranch);

        if (ast.elseBranch !is null)
        {
            if (ast.elseBranch.kind == NodeKind.IfStmt) {
                auto block = new HirBlock();
                block.stmts ~= lowerIf(cast(IfStmt) ast.elseBranch);
                stmt.elseBlock = block;
            } else
                stmt.elseBlock = lowerBlock(cast(BlockStmt) ast.elseBranch);
        }

        return stmt;
    }

    HirNode lowerFor(ForStmt ast)
    {
        auto f = new HirFor();
        f.init_ = lowerStmt(ast.init_); 
        f.condition = lowerExpr(ast.condition);
        f.increment = lowerExpr(ast.increment);
        f.body = lowerBlock(cast(BlockStmt) ast.body);
        return f;
    }

    HirNode lowerWhile(WhileStmt ast)
    {
        auto f = new HirWhile();
        f.condition = lowerExpr(ast.condition);
        f.body = lowerBlock(cast(BlockStmt) ast.body);
        return f;
    }

    HirNode lowerAssign(AssignDecl ast)
    {
        HirAssignDecl assign = new HirAssignDecl;
        assign.op = ast.op;
        assign.target = lowerLValue(ast.left);
        assign.value = lowerExpr(ast.right);
        return assign;
    }

    HirNode lowerLValue(Node node)
    {
        switch(node.kind)
        {
            case NodeKind.Identifier:
                auto id = cast(Identifier) node;
                auto addr = new HirAddrOf();
                addr.varName = id.value.get!string;
                addr.type = id.resolvedType;
                return addr;
            
            case NodeKind.UnaryExpr: 
                auto un = cast(UnaryExpr) node;
                if (un.op == "*") {
                    auto deref = new HirDeref();
                    deref.ptr = lowerExpr(un.operand);  // Avalia ptr
                    deref.type = un.resolvedType;
                    return deref;
                }
            break;
            
            case NodeKind.IndexExpr: 
                auto lvalue = lowerIndex(cast(IndexExpr) node);
                return lvalue;

            case NodeKind.MemberExpr:
                return lowerMember(cast(MemberExpr) node);
            
            default: break;
        }
        return lowerExpr(node); 
    }

    HirNode lowerExpr(Node node)
    {
        if (node is null) return null;

        switch (node.kind)
        {
            case NodeKind.IntLit:
                return new HirIntLit((cast(IntLit)node).value.get!int, node.resolvedType);
            case NodeKind.LongLit:
                return new HirIntLit((cast(LongLit)node).value.get!long, node.resolvedType);
            case NodeKind.FloatLit:
                return new HirFloatLit((cast(FloatLit)node).value.get!float, node.resolvedType);
            case NodeKind.DoubleLit:
                return new HirFloatLit((cast(DoubleLit)node).value.get!double, node.resolvedType);
            case NodeKind.BoolLit:
                return new HirBoolLit((cast(BoolLit)node).value.get!bool, node.resolvedType);
            case NodeKind.CharLit:
                return new HirCharLit((cast(CharLit)node).value.get!char, node.resolvedType);
            case NodeKind.StringLit:
                return new HirStringLit((cast(StringLit)node).value.get!string, new PrimitiveType(BaseType.String));
            case NodeKind.NullLit:
                return new HirNullLit(node.resolvedType);
            case NodeKind.ArrayLit:
                return lowerArrayLit(cast(ArrayLit) node);
            case NodeKind.StructLit:
                return lowerStructLit(cast(StructLit) node);

            case NodeKind.BinaryExpr:   return lowerBinary(cast(BinaryExpr) node);
            case NodeKind.UnaryExpr:    return lowerUnary(cast(UnaryExpr) node);
            case NodeKind.TernaryExpr:  return lowerTernary(cast(TernaryExpr) node);
            case NodeKind.CastExpr:     return lowerCast(cast(CastExpr) node);
            case NodeKind.SizeOfExpr:   return lowerSizeOf(cast(SizeOfExpr) node);

            case NodeKind.Identifier:   return lowerIdentifier(cast(Identifier) node);
            case NodeKind.CallExpr:     return lowerCall(cast(CallExpr) node);
            case NodeKind.IndexExpr:    return lowerIndex(cast(IndexExpr) node);
            case NodeKind.MemberExpr:   return lowerMember(cast(MemberExpr) node);
            case NodeKind.AssignDecl:   return lowerAssign(cast(AssignDecl) node);

            default: 
                writeln("Expr nao implementada no HIR Lowering: ", node.kind);
                return null;
        }
    }

    HirNode lowerIdentifier(Identifier ast)
    {
       if (ast.isFunctionReference)
        {
            auto fn = new HirFunctionRef();
            if (auto fnType = cast(FunctionType) ast.resolvedType)
                fn.name = fnType.mangled !is null ? fnType.mangled : ast.value.get!string;
            else
                fn.name = ast.value.get!string;
            fn.type = ast.resolvedType;
            return fn;
        }
        auto load = new HirLoad();
        load.varName = ast.value.get!string;
        load.type = ast.resolvedType;
        return load;
    }

    HirNode lowerBinary(BinaryExpr ast)
    {
        if (ast.mangledName !is null)
        {
            auto call = new HirCallExpr();
            call.funcName = ast.mangledName; 
            call.type = ast.resolvedType;

            auto selfExpr = ast.isRight ? ast.right : ast.left;
            auto valExpr  = ast.isRight ? ast.left  : ast.right;

            call.args ~= lowerLValue(selfExpr); 
            if (ast.usesOpBinary)
                call.args ~= new HirStringLit(ast.op, new PointerType(new PrimitiveType(BaseType.Char)));
            
            call.args ~= lowerExpr(valExpr);
            return call;
        }

        if (ast.left.kind == NodeKind.AssignDecl)
        {
            auto assign = lowerAssign(cast(AssignDecl) ast.left);
            
            auto assignExpr = new HirAssignExpr();
            assignExpr.assign = cast(HirAssignDecl) assign;
            assignExpr.type = ast.left.resolvedType;
            
            auto bin = new HirBinary();
            bin.op = ast.op;
            bin.left = assignExpr;  // Retorna o valor atribuído
            bin.right = lowerExpr(ast.right);
            bin.type = ast.resolvedType;
            return bin;
        }

        auto bin = new HirBinary();
        bin.op = ast.op;
        bin.left = lowerExpr(ast.left);
        bin.right = lowerExpr(ast.right);
        bin.type = ast.resolvedType;
        return bin;
    }

    HirNode lowerUnary(UnaryExpr ast)
    {
        // Caso especial: dereferência
        if (ast.op == "*")
        {
            auto deref = new HirDeref();
            deref.ptr = lowerExpr(ast.operand);
            deref.type = ast.resolvedType;
            return deref;
        }
        // Caso especial: endereço
        if (ast.op == "&")
        {
            // Se é &var (identificador simples)
            if (auto id = cast(Identifier) ast.operand)
            {
                auto addr = new HirAddrOf();
                addr.varName = id.value.get!string;
                addr.type = ast.resolvedType;
                return addr;
            }
            // Para expressões complexas: &array[i], &obj.field, etc
            // Cria um nó especial que o MIR vai tratar diferente
            else {
                auto complex = new HirAddrOfComplex(
                    lowerExpr(ast.operand),  // Converte para HIR
                    ast.resolvedType
                );
                return complex;
            }
        }
        // Outros operadores unários (-, !, ~, ++, --)
        auto un = new HirUnary();
        un.op = ast.op;
        un.operand = lowerExpr(ast.operand);
        un.type = ast.resolvedType;
        return un;
    }

    HirNode lowerTernary(TernaryExpr ast)
    {
        auto t = new HirTernary();
        t.condition = lowerExpr(ast.condition);
        t.trueExpr = lowerExpr(ast.trueExpr);
        t.falseExpr = lowerExpr(ast.falseExpr);
        t.type = ast.resolvedType;
        return t;
    }

    HirNode lowerCast(CastExpr ast)
    {
        auto c = new HirCast();
        c.targetType = ast.resolvedType;
        c.type = ast.resolvedType;
        c.value = lowerExpr(ast.from);
        return c;
    }

    HirNode lowerCall(CallExpr ast)
    {
        auto call = new HirCallExpr();
        call.type = ast.resolvedType;
        call.isVarArg = ast.isVarArg;
        call.isExternalCall = ast.isExternalCall;
        call.refType = ast.refType;
        call.isRef = ast.isRef;

        // Verifica se é chamada de método (MemberExpr)
        if (auto mem = cast(MemberExpr) ast.id)
        {
            Type targetType = mem.target.resolvedType;
            ast.id.resolvedType = targetType;
            string structName;
            
            if (auto st = cast(StructType) targetType) structName = st.name;
            else if (auto pt = cast(PointerType) targetType) structName = (cast(StructType)pt.pointeeType).name;
            
            call.funcName = ast.mangledName;
            HirNode thisArg;
            if (cast(StructType) targetType)
                thisArg = lowerLValue(mem.target);
            else
                thisArg = lowerExpr(mem.target);
            
            call.args ~= thisArg;
        } 
        else if (auto id = cast(Identifier) ast.id)
            call.funcName = ast.mangledName;
        else if (auto str = cast(StringLit) ast.id)
            call.funcName = str.value.get!string;
        
        foreach(i, arg; ast.args)
            call.args ~= lowerExpr(arg);

        return call;
    }

    HirNode lowerIndex(IndexExpr ast)
    {
        auto idx = new HirIndexExpr();
        idx.index = lowerExpr(ast.index);
        idx.target = lowerExpr(ast.target);
        if (ast.mangledName !is null)
        {
            auto call = new HirCallExpr();
            call.funcName = ast.mangledName; 
            call.type = ast.resolvedType;
            call.args ~= lowerLValue(ast.target);
            call.args ~= idx.index;
            return call;
        }
        idx.type = ast.resolvedType;
        return idx;
    }

    HirNode lowerArrayLit(ArrayLit ast)
    {
        auto arr = new HirArrayLit(ast.resolvedType);
        foreach(elem; ast.elements) arr.elements ~= lowerExpr(elem);
        return arr;
    }

    HirNode lowerSizeOf(SizeOfExpr ast) 
    {
        long size = calculateTypeSize(ast.resolvedType_);
        return new HirIntLit(size, new PrimitiveType(BaseType.Int));
    }

    long calculateTypeSize(Type t) 
    {
        if (PrimitiveType prim = cast(PrimitiveType) t)
            switch(prim.baseType)
            {
                case BaseType.Bool: return 1;
                case BaseType.Char: return 1;
                case BaseType.Int: return 4;
                case BaseType.Long: return 8;
                case BaseType.Float: return 4;
                case BaseType.Double: return 8;
                case BaseType.String: return 8; // Ponteiro + Tamanho (ou apenas ptr)
                default: return 8;
            }
        
        if (auto st = cast(StructType) t)
        {
            if (st.mangledName in structSizes)
                return structSizes[st.mangledName];
            writeln(structSizes);
            writeln("Warning: Size of struct ", st.name, " not found, assuming 0.");
            return 0;
        }

        if (auto st = cast(UnionType) t)
        {
            if (st.mangledName in structSizes)
                return structSizes[st.mangledName];
            writeln("UnionMangled: ", st.mangledName);
            writeln("Warning: Size of union ", st.name, " not found, assuming 0.");
            return 0;
        }

        if (cast(PointerType) t) return 8;
        if (ArrayType arr = cast(ArrayType) t)
            return arr.length * calculateTypeSize(arr.elementType);
        
        return 8; // Default
    }
}
