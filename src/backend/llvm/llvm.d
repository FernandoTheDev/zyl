module backend.llvm.llvm;

import core.stdc.config;

extern (C):

// Tipos básicos do LLVM
alias int64_t = long;

alias LLVMBool = int;
alias LLVMContextRef = void*;
alias LLVMModuleRef = void*;
alias LLVMBuilderRef = void*;
alias LLVMValueRef = void*;
alias LLVMTypeRef = void*;
alias LLVMBasicBlockRef = void*;
alias LLVMTargetRef = void*;
alias LLVMTargetMachineRef = void*;
alias LLVMMemoryBufferRef = void*;
alias LLVMPassManagerRef = void*;
alias LLVMExecutionEngineRef = void*;
alias LLVMMCJITMemoryManagerRef = void*;
alias LLVMPassRegistryRef = void*;
alias LLVMMetadataRef = void*;
alias LLVMNamedMDNodeRef = void*;
alias LLVMValueMetadataEntry = void*;
alias LLVMAttributeRef = void*;
alias LLVMComdatRef = void*;

alias LLVMGenericValueRef = void*;
alias LLVMTargetDataRef = void*;
alias LLVMModuleProviderRef = void*;
alias LLVMDIBuilderRef = void*;

// Enums básicos
enum LLVMIntPredicate {
    LLVMIntEQ = 32,
    LLVMIntNE = 33,
    LLVMIntUGT = 34,
    LLVMIntUGE = 35,
    LLVMIntULT = 36,
    LLVMIntULE = 37,
    LLVMIntSGT = 38,
    LLVMIntSGE = 39,
    LLVMIntSLT = 40,
    LLVMIntSLE = 41
}

enum LLVMTypeKind
{
    LLVMVoidTypeKind = 0,
    LLVMHalfTypeKind,
    LLVMFloatTypeKind,
    LLVMDoubleTypeKind,
    LLVMX86_FP80TypeKind,
    LLVMFP128TypeKind,
    LLVMPPC_FP128TypeKind,
    LLVMLabelTypeKind,
    LLVMIntegerTypeKind,
    LLVMFunctionTypeKind,
    LLVMStructTypeKind,
    LLVMArrayTypeKind,
    LLVMPointerTypeKind,
    LLVMVectorTypeKind,
    LLVMMetadataTypeKind,
    LLVMX86_MMXTypeKind,
    LLVMTokenTypeKind,
    LLVMScalableVectorTypeKind,
    LLVMBFloatTypeKind,
    LLVMX86_AMXTypeKind,
    LLVMTargetExtTypeKind,
}

enum LLVMOpcode {
    LLVMRet = 1,
    LLVMBr = 2,
    LLVMSwitch = 3,
    // ... (muitos outros) ...
    LLVMAlloca = 28, // <-- O número 28 é o padrão para Alloca
    LLVMLoad = 29,
    LLVMStore = 30,
    // ...
}

enum LLVMRealPredicate {
    LLVMRealPredicateFalse = 0,
    LLVMRealOEQ = 1, // Ordered Equal
    LLVMRealOGT = 2, // Ordered Greater Than
    LLVMRealOGE = 3, // Ordered Greater or Equal
    LLVMRealOLT = 4, // Ordered Less Than
    LLVMRealOLE = 5, // Ordered Less or Equal
    LLVMRealONE = 6, // Ordered Not Equal
    // ... existem outros, mas esses bastam
}

enum LLVMCodeGenOptLevel
{
        LLVMCodeGenLevelNone = 0,
        LLVMCodeGenLevelLess,
        LLVMCodeGenLevelDefault,
        LLVMCodeGenLevelAggressive
}

enum LLVMRelocMode
{
        LLVMRelocDefault = 0,
        LLVMRelocStatic,
        LLVMRelocPIC,
        LLVMRelocDynamicNoPIC
}

enum LLVMCodeModel
{
        LLVMCodeModelDefault = 0,
        LLVMCodeModelJITDefault,
        LLVMCodeModelTiny,
        LLVMCodeModelSmall,
        LLVMCodeModelKernel,
        LLVMCodeModelMedium,
        LLVMCodeModelLarge
}

// Aritmética Float
LLVMValueRef LLVMBuildFAdd(LLVMBuilderRef B, LLVMValueRef LHS, LLVMValueRef RHS, const(char) *Name);
LLVMValueRef LLVMBuildFSub(LLVMBuilderRef B, LLVMValueRef LHS, LLVMValueRef RHS, const(char) *Name);
LLVMValueRef LLVMBuildFMul(LLVMBuilderRef B, LLVMValueRef LHS, LLVMValueRef RHS, const(char) *Name);
LLVMValueRef LLVMBuildFDiv(LLVMBuilderRef B, LLVMValueRef LHS, LLVMValueRef RHS, const(char) *Name);
    
// Comparação Float
LLVMValueRef LLVMBuildFCmp(LLVMBuilderRef B, LLVMRealPredicate Op, LLVMValueRef LHS, LLVMValueRef RHS, const(char) *Name);

// Retorna o Kind (categoria) de um tipo
LLVMTypeKind LLVMGetTypeKind(LLVMTypeRef Ty);
// Retorna o tipo de retorno de um FunctionType
LLVMTypeRef LLVMGetReturnType(LLVMTypeRef FunctionTy);
LLVMOpcode LLVMGetInstructionOpcode(LLVMValueRef Inst);

// Funções Core
LLVMContextRef LLVMContextCreate();
void LLVMContextDispose(LLVMContextRef C);

LLVMModuleRef LLVMModuleCreateWithName(const(char)* ModuleID);
void LLVMDisposeModule(LLVMModuleRef M);
void LLVMDumpModule(LLVMModuleRef M);
int LLVMPrintModuleToFile(LLVMModuleRef M, const(char)* Filename, char** ErrorMessage);

LLVMBuilderRef LLVMCreateBuilderInContext(LLVMContextRef C);
void LLVMDisposeBuilder(LLVMBuilderRef Builder);

// Tipos
LLVMTypeRef LLVMInt32TypeInContext(LLVMContextRef C);
LLVMTypeRef LLVMInt64TypeInContext(LLVMContextRef C);
LLVMTypeRef LLVMInt8TypeInContext(LLVMContextRef C); // Char/Bool
LLVMTypeRef LLVMInt1TypeInContext(LLVMContextRef C); 
LLVMTypeRef LLVMFloatTypeInContext(LLVMContextRef C);
LLVMTypeRef LLVMDoubleTypeInContext(LLVMContextRef C);
LLVMTypeRef LLVMVoidTypeInContext(LLVMContextRef C);
LLVMTypeRef LLVMPointerType(LLVMTypeRef ElementType, uint AddressSpace); // Legacy pointer type logic
LLVMTypeRef LLVMPointerTypeInContext(LLVMContextRef C, uint AddressSpace); // Opaque Pointers (LLVM 15+)
LLVMTypeRef LLVMArrayType(LLVMTypeRef ElementType, uint ElementCount);

// Funções
LLVMTypeRef LLVMFunctionType(LLVMTypeRef ReturnType, LLVMTypeRef* ParamTypes, uint ParamCount, int IsVarArg);
LLVMValueRef LLVMAddFunction(LLVMModuleRef M, const(char)* Name, LLVMTypeRef FunctionTy);
LLVMBasicBlockRef LLVMAppendBasicBlockInContext(LLVMContextRef C, LLVMValueRef Fn, const(char)* Name);
void LLVMPositionBuilderAtEnd(LLVMBuilderRef Builder, LLVMBasicBlockRef Block);
LLVMValueRef LLVMGetParam(LLVMValueRef Fn, uint Index);
uint LLVMCountParams(LLVMValueRef Fn);
void LLVMGetParams(LLVMValueRef Fn, LLVMValueRef* Params);

// Constantes
LLVMValueRef LLVMConstInt(LLVMTypeRef IntTy, ulong N, int SignExtend);
LLVMValueRef LLVMConstReal(LLVMTypeRef RealTy, double N);
LLVMValueRef LLVMConstStringInContext(LLVMContextRef C, const(char)* Str, uint Length, int DontNullTerminate);
LLVMValueRef LLVMConstNull(LLVMTypeRef Ty);

// Instruções - Build
LLVMValueRef LLVMBuildRet(LLVMBuilderRef, LLVMValueRef V);
LLVMValueRef LLVMBuildRetVoid(LLVMBuilderRef);
LLVMValueRef LLVMBuildAlloca(LLVMBuilderRef, LLVMTypeRef Ty, const(char)* Name);
LLVMValueRef LLVMBuildStore(LLVMBuilderRef, LLVMValueRef Val, LLVMValueRef Ptr);
LLVMValueRef LLVMBuildLoad2(LLVMBuilderRef, LLVMTypeRef Ty, LLVMValueRef PointerVal, const(char)* Name);
LLVMValueRef LLVMBuildCall2(LLVMBuilderRef, LLVMTypeRef Ty, LLVMValueRef Fn, LLVMValueRef* Args, uint NumArgs, const(char)* Name);

// Aritmética
LLVMValueRef LLVMBuildAdd(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS, const(char)* Name);
LLVMValueRef LLVMBuildSub(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS, const(char)* Name);
LLVMValueRef LLVMBuildMul(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS, const(char)* Name);
LLVMValueRef LLVMBuildSDiv(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS, const(char)* Name);

// Casts & GEP
LLVMValueRef LLVMBuildBitCast(LLVMBuilderRef, LLVMValueRef Val, LLVMTypeRef DestTy, const(char)* Name);
LLVMValueRef LLVMBuildIntToPtr(LLVMBuilderRef, LLVMValueRef Val, LLVMTypeRef DestTy, const(char)* Name);
LLVMValueRef LLVMBuildPtrToInt(LLVMBuilderRef, LLVMValueRef Val, LLVMTypeRef DestTy, const(char)* Name);
LLVMValueRef LLVMBuildZExt(LLVMBuilderRef, LLVMValueRef Val, LLVMTypeRef DestTy, const(char)* Name);
LLVMValueRef LLVMBuildFPExt(LLVMBuilderRef, LLVMValueRef Val, LLVMTypeRef DestTy, const(char)* Name);
LLVMValueRef LLVMBuildFPToSI(LLVMBuilderRef, LLVMValueRef Val, LLVMTypeRef DestTy, const(char)* Name); // Float -> Int

// 2. Extensão de Inteiro (Sign Extend)
// Ex: int a = 10; long b = (long)a; (32 bits -> 64 bits mantendo sinal)
LLVMValueRef LLVMBuildSExt(LLVMBuilderRef, LLVMValueRef Val, LLVMTypeRef DestTy, const(char)* Name);
// 3. Truncamento de Inteiro (Truncate)
// Ex: long a = 10; int b = (int)a; (64 bits -> 32 bits, corta os bits superiores)
LLVMValueRef LLVMBuildTrunc(LLVMBuilderRef, LLVMValueRef Val, LLVMTypeRef DestTy, const(char)* Name);
// 5. Truncamento de Float (Floating Point Truncate)
// Ex: double a = 5.5; float b = (float)a; (64 bits -> 32 bits, perde precisão)
LLVMValueRef LLVMBuildFPTrunc(LLVMBuilderRef, LLVMValueRef Val, LLVMTypeRef DestTy, const(char)* Name);

LLVMValueRef LLVMBuildGEP2(LLVMBuilderRef B, LLVMTypeRef Ty, LLVMValueRef Pointer, LLVMValueRef *Indices, uint NumIndices, const(char) *Name);

// Controle de Fluxo
LLVMValueRef LLVMBuildICmp(LLVMBuilderRef, LLVMIntPredicate Op, LLVMValueRef LHS, LLVMValueRef RHS, const(char)* Name);
LLVMValueRef LLVMBuildBr(LLVMBuilderRef, LLVMBasicBlockRef Dest);
LLVMValueRef LLVMBuildCondBr(LLVMBuilderRef, LLVMValueRef If, LLVMBasicBlockRef Then, LLVMBasicBlockRef Else);
LLVMBasicBlockRef LLVMGetInsertBlock(LLVMBuilderRef Builder);
LLVMValueRef LLVMGetBasicBlockParent(LLVMBasicBlockRef BB);
LLVMValueRef LLVMBuildGlobalStringPtr(LLVMBuilderRef B, const(char)* Str, const(char)* Name);
LLVMValueRef LLVMBuildSIToFP(LLVMBuilderRef B, LLVMValueRef Val, LLVMTypeRef DestTy, const(char)* Name);
LLVMTypeRef LLVMGetAllocatedType(LLVMValueRef Alloca);
LLVMTypeRef LLVMTypeOf(LLVMValueRef Val);
int LLVMIsFunctionVarArg(LLVMValueRef Fn);
LLVMTypeRef LLVMGetElementType(LLVMTypeRef Ty);
LLVMValueRef LLVMIsAAllocaInst(LLVMValueRef Val);
LLVMValueRef LLVMBuildGEP2(LLVMBuilderRef B, LLVMTypeRef Ty, LLVMValueRef Pointer, LLVMValueRef *Indices, 
    uint NumIndices, const(char) *Name);
LLVMValueRef LLVMBuildShl(LLVMBuilderRef B, LLVMValueRef LHS, LLVMValueRef RHS, const(char)* Name);
LLVMValueRef LLVMBuildAShr(LLVMBuilderRef B, LLVMValueRef LHS, LLVMValueRef RHS, const(char)* Name);
LLVMTypeRef LLVMDoubleTypeInContext(LLVMContextRef C);

// TARGETS //

// X86
void LLVMInitializeX86Target();
void LLVMInitializeX86TargetInfo();
void LLVMInitializeX86TargetMC();
void LLVMInitializeX86AsmPrinter();
void LLVMInitializeX86AsmParser();

// AArch64
void LLVMInitializeAArch64Target();
void LLVMInitializeAArch64TargetInfo();
void LLVMInitializeAArch64TargetMC();
void LLVMInitializeAArch64AsmPrinter();
void LLVMInitializeAArch64AsmParser();

// ARM
void LLVMInitializeARMTarget();
void LLVMInitializeARMTargetInfo();
void LLVMInitializeARMTargetMC();
void LLVMInitializeARMAsmPrinter();
void LLVMInitializeARMAsmParser();

// Target
LLVMBool LLVMInitializeNativeTarget();
LLVMBool LLVMInitializeNativeAsmPrinter();
LLVMBool LLVMInitializeNativeAsmParser();
LLVMTargetRef LLVMGetFirstTarget();
LLVMTargetRef LLVMGetNextTarget(LLVMTargetRef T);
LLVMTargetRef LLVMGetTargetFromName(const(char)* Name);
LLVMBool LLVMGetTargetFromTriple(const(char)* Triple, LLVMTargetRef* T, const(char)** ErrorMessage);
const(char)* LLVMGetTargetName(LLVMTargetRef T);
const(char)* LLVMGetTargetDescription(LLVMTargetRef T);
void LLVMDisposeTargetMachine(LLVMTargetMachineRef T);
LLVMTargetDataRef LLVMCreateTargetData(const(char)* StringRep);
void LLVMDisposeTargetData(LLVMTargetDataRef TD);
LLVMTargetDataRef LLVMCopyTargetData(LLVMTargetDataRef TD);
const(char)* LLVMGetTargetMachineTriple(LLVMTargetMachineRef T);
LLVMTargetRef LLVMGetTargetMachineTarget(LLVMTargetMachineRef T);
const(char)* LLVMGetTargetMachineCPU(LLVMTargetMachineRef T);
const(char)* LLVMGetTargetMachineFeatureString(LLVMTargetMachineRef T);
LLVMTargetDataRef LLVMGetTargetMachineData(LLVMTargetMachineRef T);

void LLVMDisposeMessage(char* Message);
LLVMTargetMachineRef LLVMCreateTargetMachine(LLVMTargetRef T, const(char)* Triple, const(char)* CPU, const(
                char)* Features, LLVMCodeGenOptLevel Level, LLVMRelocMode Reloc, LLVMCodeModel CodeModel);
LLVMTargetDataRef LLVMCreateTargetDataLayout(LLVMTargetMachineRef T);
const(char)* LLVMCopyStringRepOfTargetData(LLVMTargetDataRef TD);
void LLVMSetDataLayout(LLVMModuleRef M, const(char)* DataLayout);
void LLVMSetTarget(LLVMModuleRef M, const(char)* Triple);
LLVMTypeRef LLVMInt8Type();
LLVMValueRef LLVMBuildExtractValue(LLVMBuilderRef B, LLVMValueRef agg, uint index, const(char)* name);
LLVMTypeRef LLVMStructTypeInContext(LLVMContextRef Ctx,
                                    LLVMTypeRef *ElementTypes,
                                    uint ElementCount,
                                    LLVMBool Packed);
LLVMTypeRef LLVMStructTypeInContext(LLVMContextRef Ctx,
                                    LLVMTypeRef *ElementTypes,
                                    uint ElementCount,
                                    LLVMBool Packed);
LLVMTypeRef LLVMStructCreateNamed(LLVMContextRef C, const(char)* Name);
// Define o corpo (campos) de uma struct previamente criada
// Packed = 0 (false) para alinhamento natural, 1 (true) para packed
void LLVMStructSetBody(LLVMTypeRef StructTy, LLVMTypeRef* ElementTypes, uint ElementCount, LLVMBool Packed);    
// Opcional: Útil se você precisar de structs literais constantes depois
LLVMValueRef LLVMConstNamedStruct(LLVMTypeRef StructTy, LLVMValueRef* ConstantVals, uint Count);
LLVMValueRef LLVMBuildSRem(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS, const char* Name);
LLVMValueRef LLVMBuildURem(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS, const char* Name);
LLVMValueRef LLVMBuildFRem(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS, const char* Name);
LLVMValueRef LLVMBuildAnd(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS, const char* Name);
LLVMValueRef LLVMBuildOr(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS, const char* Name);
LLVMValueRef LLVMBuildXor(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS, const char* Name);
void LLVMSetGlobalConstant(LLVMValueRef GlobalVar, bool IsConstant);
void LLVMSetLinkage(LLVMValueRef GlobalVar, int Linkage);
void LLVMSetGlobalAlignment(LLVMValueRef GlobalVar, uint Align);
LLVMValueRef LLVMAddGlobal(LLVMModuleRef M, LLVMTypeRef Ty, const(char)* Name);
void LLVMSetInitializer(LLVMValueRef GlobalVar, LLVMValueRef ConstantVal);
LLVMValueRef LLVMGetNamedGlobal(LLVMModuleRef M, const(char)* Name);
LLVMValueRef LLVMBuildFNeg(LLVMBuilderRef, LLVMValueRef, const(char)*);
LLVMValueRef LLVMConstArray2(LLVMTypeRef ElementType,
                             LLVMValueRef *ConstantVals,
                             size_t Length);
void LLVMSetValueName2(LLVMValueRef Val, const char *Name, size_t NameLen);
ulong LLVMStoreSizeOfType(LLVMTargetDataRef td, LLVMTypeRef ty);
