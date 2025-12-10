module backend.llvm.codegen_mod;

import backend.llvm.llvm;
import middle.mir.mir;
import frontend.types.type;
import std.string : toStringz;
import std.stdio;

mixin template CodeGenModule() {
    void emitProgram(MirProgram prog)
    {
        foreach (func; prog.functions)
            declareFunction(func);
            
        foreach (func; prog.functions)
            emitFunction(func);
    }

    private void declareFunction(MirFunction func) 
    {
        LLVMTypeRef retType = toLLVMType(func.returnType);

        LLVMTypeRef[] paramTypes;

        foreach (i, paramType; func.paramTypes) 
        {
            if (paramType is null) 
                break;
            paramTypes ~= toLLVMType(paramType);
        }

        LLVMTypeRef funcTy = LLVMFunctionType(
            retType, 
            paramTypes.ptr, 
            cast(uint)paramTypes.length, 
            func.isVarArg ? 1 : 0
        );

        LLVMValueRef llvmFunc = LLVMAddFunction(module_, toStringz(func.name), funcTy);

        funcMap[func.name] = llvmFunc;
        funcTypeMap[func.name] = funcTy;

        for (int i = 0; i < paramTypes.length; i++)
        {
            LLVMValueRef param = LLVMGetParam(llvmFunc, i);
            if (func.isVarArg && i == func.isVarArgAt)
                LLVMSetValueName2(param, "_vacount", 8);
        }
    }
}   
