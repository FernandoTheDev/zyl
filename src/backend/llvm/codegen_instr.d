module backend.llvm.codegen_instr;

import backend.llvm.llvm;
import middle.mir.mir;
import frontend.types.type;
import std.string : toStringz;
import std.stdio;

mixin template CodeGenInstr() {
    
    void emitInstr(MirInstr instr) 
    {
        switch (instr.op) {
            case MirOp.Alloca:
                LLVMTypeRef allocType;
                if (auto ptrT = cast(PointerType) instr.dest.type)
                     allocType = toLLVMType(ptrT.pointeeType);
                else
                     allocType = LLVMInt64TypeInContext(context);
                
                LLVMValueRef val = LLVMBuildAlloca(builder, allocType, "stack");
                setReg(instr.dest, val);
                break;

            case MirOp.Store:
                LLVMValueRef v = getLLVMValue(instr.operands[0]);
                LLVMValueRef p = getLLVMValue(instr.operands[1]);
                LLVMBuildStore(builder, v, p);
                break;

            case MirOp.Load:
                LLVMValueRef p = getLLVMValue(instr.operands[0]);
                LLVMTypeRef ty = toLLVMType(instr.dest.type);
                LLVMValueRef res = LLVMBuildLoad2(builder, ty, p, "load");
                setReg(instr.dest, res);
                break;

            case MirOp.Br:
                string label = instr.operands[0].constStr;
                LLVMBasicBlockRef targetBB = blockMap[label];
                LLVMBuildBr(builder, targetBB);
                break;

            case MirOp.CondBr:
                LLVMValueRef cond = getLLVMValue(instr.operands[0]);
                string thenLabel = instr.operands[1].constStr;
                string elseLabel = instr.operands[2].constStr;
                LLVMBuildCondBr(builder, cond, blockMap[thenLabel], blockMap[elseLabel]);
                break;

            case MirOp.ICmp:
                LLVMValueRef l = getLLVMValue(instr.operands[0]);
                LLVMValueRef r = getLLVMValue(instr.operands[1]);
                string op = instr.operands[2].constStr;
                LLVMIntPredicate pred;

                if (op == "==") pred = LLVMIntPredicate.LLVMIntEQ;
                else if (op == "!=") pred = LLVMIntPredicate.LLVMIntNE;
                else if (op == "<")  pred = LLVMIntPredicate.LLVMIntSLT;
                else if (op == "<=") pred = LLVMIntPredicate.LLVMIntSLE;
                else if (op == ">")  pred = LLVMIntPredicate.LLVMIntSGT;
                else if (op == ">=") pred = LLVMIntPredicate.LLVMIntSGE;
                else pred = LLVMIntPredicate.LLVMIntEQ;

                setReg(instr.dest, LLVMBuildICmp(builder, pred, l, r, "cmp")); 
                break;
                
            case MirOp.Add:
                setReg(instr.dest, LLVMBuildAdd(builder, 
                    getLLVMValue(instr.operands[0]), 
                    getLLVMValue(instr.operands[1]), "add"));
                break;

            case MirOp.Sub:
                setReg(instr.dest, LLVMBuildSub(builder, 
                    getLLVMValue(instr.operands[0]), 
                    getLLVMValue(instr.operands[1]), "sub"));
                break;

            case MirOp.Mul:
                setReg(instr.dest, LLVMBuildMul(builder, 
                    getLLVMValue(instr.operands[0]), 
                    getLLVMValue(instr.operands[1]), "mul"));
                break;

            case MirOp.Div:
                setReg(instr.dest, LLVMBuildSDiv(builder, 
                    getLLVMValue(instr.operands[0]), 
                    getLLVMValue(instr.operands[1]), "sdiv"));
                break;

            case MirOp.Ret:
                if (instr.operands.length > 0)
                    LLVMBuildRet(builder, getLLVMValue(instr.operands[0]));
                else
                    LLVMBuildRetVoid(builder);
                break;

            
            case MirOp.Call:
                // O operando 0 é o CALLEE (quem será chamado)
                MirValue calleeVal = instr.operands[0];

                LLVMValueRef funcPtr;
                LLVMTypeRef funcSig;

                string name = calleeVal.constStr;

                if (name in funcMap) 
                {
                    // Chamada direta - função declarada no módulo
                    funcPtr = funcMap[name];
                    funcSig = funcTypeMap[name];
                }
                else 
                {
                    // Chamada por referência - função passada como parâmetro/variável
                    LLVMValueRef ptrVal;
                    if (calleeVal.isConst && calleeVal.isRef)
                    {
                        // É uma referência constante (nome de função passada como argumento)
                        // Mas como não está no funcMap, deve estar em vregMap
                        if (calleeVal.regIndex < vregMap.length && vregMap[calleeVal.regIndex] !is null)
                            ptrVal = vregMap[calleeVal.regIndex];
                        else
                        {
                            writeln("ERRO [Call]: Não encontrado em vregMap!");
                            writeln("vregMap.length = ", vregMap.length);
                            break;
                        }
                    }
                    else
                        ptrVal = getLLVMValue(calleeVal);
                    
                    // Verifica o tipo do valor obtido
                    auto ptrValType = LLVMTypeOf(ptrVal);
                    auto ptrValTypeKind = LLVMGetTypeKind(ptrValType);

                    // Se é um ponteiro armazenado na stack (alloca), precisa fazer Load
                    if (ptrValTypeKind == LLVMTypeKind.LLVMPointerTypeKind)
                    {
                        // Verifica se não é já um ponteiro de função global
                        // (ponteiros de função globais não precisam de Load)
                        ulong nameLen;
                        auto ptrName = LLVMGetValueName2(ptrVal, &nameLen);
                        import std.string : fromStringz;
                        string ptrNameStr = fromStringz(ptrName).idup;

                        // Se começa com "stack", é uma alloca e precisa de Load
                        if (ptrNameStr.length >= 5 && ptrNameStr[0..5] == "stack")
                        {
                            funcPtr = LLVMBuildLoad2(builder, 
                                LLVMPointerTypeInContext(context, 0), 
                                ptrVal, 
                                "func_ptr_load");
                        }
                        else
                            funcPtr = ptrVal;
                    }
                    else
                        funcPtr = ptrVal;
                    
                    if (calleeVal.isRef && calleeVal.refType !is null)
                        funcSig = toLLVMFunctionType(calleeVal.refType);
                    else if (auto fnType = cast(FunctionType) calleeVal.type) 
                        funcSig = toLLVMFunctionType(fnType);
                    else 
                    {
                        writeln("ERRO [Call]: Sem tipo de função válido!");
                        writeln("NAME: ", name);
                        writeln("TYPE: ", calleeVal.type.toStr());
                        writeln("isRef: ", calleeVal.isRef);
                        writeln("refType: ", calleeVal.refType);
                        break;
                    }
                }

                LLVMTypeRef returnType = LLVMGetReturnType(funcSig);
                bool isVoid = (LLVMGetTypeKind(returnType) == LLVMTypeKind.LLVMVoidTypeKind);

                // Construir argumentos
                LLVMValueRef[] args;
                foreach(op; instr.operands[1..$])
                    args ~= getLLVMValue(op);

                const(char)* n = isVoid ? "" : "call_res";
                LLVMValueRef res = LLVMBuildCall2(
                    builder, 
                    funcSig,
                    funcPtr, 
                    args.ptr, 
                    cast(uint)args.length, 
                    n
                );

                if (!isVoid)
                    setReg(instr.dest, res);
                break;
            
            case MirOp.GetElementPtr:
                LLVMValueRef baseVal = getLLVMValue(instr.operands[0]);
                LLVMValueRef[] indices; 
                
                auto baseType = instr.operands[0].type;
                
                // Verifica se estamos acessando um Array através de um ponteiro (Array Decay)
                // Se a base é `[10 x int]*`, precisamos de índices `0, i` para pegar o elemento `i`.
                // Se a base é `int*`, precisamos apenas de índice `i`.
                
                if (auto ptrT = cast(PointerType) baseType)
                    if (cast(ArrayType) ptrT.pointeeType)
                        indices ~= LLVMConstInt(LLVMInt32TypeInContext(context), 0, 0);
                
                foreach(op; instr.operands[1..$])
                    indices ~= getLLVMValue(op);

                LLVMTypeRef elemType;
                
                if (PointerType ptrType = cast(PointerType) baseType)
                    // O tipo base para o cálculo do GEP é sempre o tipo apontado
                    elemType = toLLVMType(ptrType.pointeeType);
                else 
                {
                    if (auto prim = cast(PrimitiveType) baseType)
                         if (prim.baseType == BaseType.String) elemType = LLVMInt8TypeInContext(context);
                         else elemType = toLLVMType(baseType);
                    else
                         elemType = toLLVMType(baseType);
                }

                LLVMValueRef res = LLVMBuildGEP2(
                    builder, 
                    elemType,      
                    baseVal,       
                    indices.ptr,   
                    cast(uint)indices.length, 
                    "gep"
                );

                setReg(instr.dest, res);
                break;

            case MirOp.BitCast:
                LLVMValueRef val = getLLVMValue(instr.operands[0]);
                LLVMTypeRef targetTy = toLLVMType(instr.dest.type);
                setReg(instr.dest, LLVMBuildBitCast(builder, val, targetTy, "cast"));
                break;

            case MirOp.IntToPtr:
                LLVMValueRef val = getLLVMValue(instr.operands[0]);
                LLVMTypeRef targetTy = toLLVMType(instr.dest.type);
                setReg(instr.dest, LLVMBuildIntToPtr(builder, val, targetTy, "inttptr"));
                break;

            case MirOp.PtrToInt:
                LLVMValueRef val = getLLVMValue(instr.operands[0]);
                LLVMTypeRef targetTy = toLLVMType(instr.dest.type);
                setReg(instr.dest, LLVMBuildPtrToInt(builder, val, targetTy, "ptrtint"));
                break;

            case MirOp.SIToFP:
                LLVMValueRef val = getLLVMValue(instr.operands[0]);
                LLVMTypeRef targetTy = toLLVMType(instr.dest.type);
                setReg(instr.dest, LLVMBuildSIToFP(builder, val, targetTy, "sitofp"));
                break;

            case MirOp.FPToSI:
                LLVMValueRef val = getLLVMValue(instr.operands[0]);
                LLVMTypeRef targetTy = toLLVMType(instr.dest.type);
                setReg(instr.dest, LLVMBuildFPToSI(builder, val, targetTy, "fptosi"));
                break;

            case MirOp.SExt:
                auto res = LLVMBuildSExt(builder, getLLVMValue(instr.operands[0]), toLLVMType(instr.dest.type), "sext");
                setReg(instr.dest, res);
                break;

            case MirOp.Trunc:
                auto res = LLVMBuildTrunc(builder, getLLVMValue(instr.operands[0]), toLLVMType(instr.dest.type), 
                    "trunc");
                setReg(instr.dest, res);
                break;

            case MirOp.FPExt:
                auto res = LLVMBuildFPExt(builder, getLLVMValue(instr.operands[0]), toLLVMType(instr.dest.type), 
                    "fpext");
                setReg(instr.dest, res);
                break;
                
            case MirOp.FPTrunc:
                auto res = LLVMBuildFPTrunc(builder, getLLVMValue(instr.operands[0]), toLLVMType(instr.dest.type), 
                    "fptrunc");
                setReg(instr.dest, res);
                break;

            case MirOp.Shl:
                LLVMValueRef lhs = getLLVMValue(instr.operands[0]);
                LLVMValueRef rhs = getLLVMValue(instr.operands[1]);
                LLVMValueRef res = LLVMBuildShl(builder, lhs, rhs, "shl_tmp");
                setReg(instr.dest, res);
                break;

            case MirOp.Shr:
                LLVMValueRef lhs = getLLVMValue(instr.operands[0]);
                LLVMValueRef rhs = getLLVMValue(instr.operands[1]);
                // Usamos Arithmetic Shift Right (AShr) para preservar o sinal de inteiros (int)
                // Se fosse unsigned, usariamos LShr.
                LLVMValueRef res = LLVMBuildAShr(builder, lhs, rhs, "shr_tmp");
                setReg(instr.dest, res);
                break;

            case MirOp.FAdd:
                auto res = LLVMBuildFAdd(builder, getLLVMValue(instr.operands[0]), getLLVMValue(instr.operands[1]), 
                    "fadd");
                setReg(instr.dest, res);
                break;

            case MirOp.FSub:
                auto res = LLVMBuildFSub(builder, getLLVMValue(instr.operands[0]), getLLVMValue(instr.operands[1]), 
                    "fsub");
                setReg(instr.dest, res);
                break;
            
            case MirOp.FMul:
                auto res = LLVMBuildFMul(builder, getLLVMValue(instr.operands[0]), getLLVMValue(instr.operands[1]), 
                    "fmul");
                setReg(instr.dest, res);
                break;
            
            case MirOp.FDiv:
                auto res = LLVMBuildFDiv(builder, getLLVMValue(instr.operands[0]), getLLVMValue(instr.operands[1]), 
                    "fdiv");
                setReg(instr.dest, res);
                break;

            case MirOp.SRem:
                auto res = LLVMBuildSRem(builder, getLLVMValue(instr.operands[0]), getLLVMValue(instr.operands[1]), 
                    "rem");
                setReg(instr.dest, res);
                break;

            case MirOp.FRem:
                auto res = LLVMBuildFRem(builder, getLLVMValue(instr.operands[0]), getLLVMValue(instr.operands[1]), 
                    "frem");
                setReg(instr.dest, res);
                break;

            case MirOp.BXor:
                auto res = LLVMBuildXor(builder, getLLVMValue(instr.operands[0]), getLLVMValue(instr.operands[1]), 
                    "xor");
                setReg(instr.dest, res);
                break;

            case MirOp.And:
                LLVMValueRef l = getLLVMValue(instr.operands[0]);
                LLVMValueRef r = getLLVMValue(instr.operands[1]);
                LLVMValueRef res = LLVMBuildAnd(builder, l, r, "and");
                setReg(instr.dest, res);
                break;

            case MirOp.Or:
                LLVMValueRef l = getLLVMValue(instr.operands[0]);
                LLVMValueRef r = getLLVMValue(instr.operands[1]);
                LLVMValueRef res = LLVMBuildOr(builder, l, r, "or");
                setReg(instr.dest, res);
                break;

            case MirOp.FNeg:
                LLVMValueRef v = getLLVMValue(instr.operands[0]);
                LLVMValueRef res = LLVMBuildFNeg(builder, v, "fneg");
                setReg(instr.dest, res);
                break;

            case MirOp.FCmp:
                string op = instr.operands[2].constStr;
                LLVMRealPredicate pred;
                
                if (op == "==") pred = LLVMRealPredicate.LLVMRealOEQ;
                else if (op == "!=") pred = LLVMRealPredicate.LLVMRealONE;
                else if (op == "<")  pred = LLVMRealPredicate.LLVMRealOLT;
                else if (op == "<=") pred = LLVMRealPredicate.LLVMRealOLE;
                else if (op == ">")  pred = LLVMRealPredicate.LLVMRealOGT;
                else if (op == ">=") pred = LLVMRealPredicate.LLVMRealOGE;
                else pred = LLVMRealPredicate.LLVMRealOEQ;

                auto res = LLVMBuildFCmp(builder, pred, getLLVMValue(instr.operands[0]), 
                    getLLVMValue(instr.operands[1]), "fcmp");
                setReg(instr.dest, res);
                break;

            default: 
                writeln("MirOp não implementado: ", instr.op);
                break;
        }
    }
}
