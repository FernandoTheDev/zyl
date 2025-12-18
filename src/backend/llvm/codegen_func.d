module backend.llvm.codegen_func;

import backend.llvm.llvm;
import middle.mir.mir;
import std.string : toStringz;
import std.stdio;

mixin template CodeGenFunc() {
    void emitFunction(MirFunction func)
    {
        LLVMValueRef llvmFunc = funcMap[func.name];
        currentFuncVal = funcMap[func.name];
        
        vregMap = [];
        vregMap.length = func.regCounter;
        blockMap.clear();
        
        if (func.blocks.length == 0)
            return;

        foreach (block; func.blocks) 
        {
            LLVMBasicBlockRef bb = LLVMAppendBasicBlockInContext(
                context, 
                llvmFunc, 
                toStringz(block.name)
            );
            blockMap[block.name] = bb;
        }

        uint paramCount = LLVMCountParams(llvmFunc);
        LLVMValueRef[] params;
        
        if (paramCount > 0) 
        {
            params.length = paramCount;
            LLVMGetParams(llvmFunc, params.ptr);
        }
        
        foreach (blockIdx, block; func.blocks) 
        {
            LLVMBasicBlockRef llvmBB = blockMap[block.name];
            LLVMPositionBuilderAtEnd(builder, llvmBB);
            foreach (instr; block.instructions)
                emitInstr(instr);
        }

        currentFuncVal = null;
    }
}
