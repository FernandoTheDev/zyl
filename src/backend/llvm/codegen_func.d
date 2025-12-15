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
        
        // Resetar estado local
        vregMap = [];
        vregMap.length = func.regCounter;
        blockMap.clear();
        
        if (func.blocks.length == 0)
            return;

        // PASSO 1: Criar TODOS os BasicBlocks
        foreach (block; func.blocks) 
        {
            LLVMBasicBlockRef bb = LLVMAppendBasicBlockInContext(
                context, 
                llvmFunc, 
                toStringz(block.name)
            );
            blockMap[block.name] = bb;
        }

        // PASSO 2: Obter parâmetros da função
        uint paramCount = LLVMCountParams(llvmFunc);
        LLVMValueRef[] params;
        
        if (paramCount > 0) 
        {
            params.length = paramCount;
            LLVMGetParams(llvmFunc, params.ptr);
        }
        
        // PASSO 3: Preencher Blocos com Instruções
        uint allocaCount = 0;
        
        foreach (blockIdx, block; func.blocks) 
        {
            LLVMBasicBlockRef llvmBB = blockMap[block.name];
            LLVMPositionBuilderAtEnd(builder, llvmBB);
            
            foreach (instr; block.instructions) {
                emitInstr(instr);
                
                // Store dos parâmetros nas allocas correspondentes (apenas no bloco de entrada)
                // if (blockIdx == 0 && 
                //     instr.op == MirOp.Alloca && 
                //     allocaCount < paramCount &&
                //     instr.dest.regIndex < vregMap.length &&
                //     vregMap[instr.dest.regIndex] !is null)
                // {
                //     LLVMValueRef allocaPtr = vregMap[instr.dest.regIndex];
                //     LLVMValueRef paramVal = params[allocaCount];
                //     LLVMBuildStore(builder, paramVal, allocaPtr);
                //     allocaCount++;
                // }
            }
        }

        currentFuncVal = null;
    }
}
