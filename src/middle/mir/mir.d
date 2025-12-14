module middle.mir.mir;

import frontend.types.type;

enum MirOp
{
    // Memória
    Alloca, Store, Load, GetElementPtr,
    
    // Aritmética
    Add, Sub, Mul, Div, Shl, Shr,
    FAdd, FSub, FMul, FDiv, FNeg, Neg, Xor, FRem, SRem, BXor, BOr, BNot,
    
    And, Or,

    // Comparação Inteira
    ICmp,
    
    // Comparação Float (NOVO)
    FCmp,
    
    // Controle
    Br, CondBr, Call, Ret,
    
    // Casts
    IntToPtr, // Inteiro -> Ponteiro (0xB8000 -> char*)
    PtrToInt, // Ponteiro -> Inteiro (char* -> long)
    BitCast, SIToFP, FPToSI, FPExt, SExt, Trunc, FPTrunc, ZExt
}

// Representa um operando: pode ser Registrador, Constante ou Referência a Bloco
struct MirValue
{
    bool isConst;
    bool isBlockLabel;
    long constInt;
    double constFloat;
    string constStr; // Usado para string literals OU nome do bloco alvo
    int regIndex; // %0, %1...
    Type type;
    bool isGlobal = false;
    bool isArrayLiteral = false; // Flag para o backend saber que é um array const
    MirValue[] elements; // Os valores constantes dentro do array
    bool isArgument = false; 
    int argIndex; // Índice do argumento na função LLVM (0, 1, 2...)

    static MirValue reg(int idx, Type t) { 
        return MirValue(false, false, 0, 0.0, "", idx, t); 
    }

    static MirValue i32(int v, Type t) { 
        return MirValue(true, false, v, 0.0, "", 0, t); 
    }

    static MirValue i64(long v, Type t) { 
        return MirValue(true, false, cast(int)v, 0.0, "", 0, t); 
    }

    static MirValue f32(float v, Type t) { 
        return MirValue(true, false, 0, cast(double)v, "", 0, t); 
    }

    static MirValue f64(double v, Type t) { 
        return MirValue(true, false, 0, v, "", 0, t); 
    }

    static MirValue boolean(bool v, Type t) { 
        return MirValue(true, false, v ? 1 : 0, 0.0, "", 0, t); 
    }

    static MirValue nullPtr(Type ptrType = null) {
        if (ptrType is null)
            ptrType = new PointerType(new PrimitiveType(BaseType.Void));
        return MirValue(true, false, 0, 0.0, "", 0, ptrType);
    }

    static MirValue block(string name) {
        return MirValue(true, true, 0, 0.0, name, 0, null);
    }

    static MirValue stringLit(string s, Type t) {
        return MirValue(true, false, 0, 0.0, s, 0, t);
    }

    static MirValue i8(ubyte val, Type type = null) {
        MirValue v;
        v.isConst = true;
        v.constInt = val;
        v.type = type;
        return v;
    }

    static MirValue global(string name, Type type)
    {
        MirValue v;
        v.isGlobal = true;
        v.constStr = name;
        v.type = type; // isso deve ser um PointerType(TypeReal)
        return v;
    }

    static MirValue argument(int idx, Type t) {
        MirValue v;
        v.isArgument = true;
        v.argIndex = idx;
        v.type = t;
        return v;
    }
}

class MirInstr {
    MirOp op;
    MirValue dest; 
    MirValue[] operands;
    
    this(MirOp op, MirValue dest = MirValue.init, MirValue[] operands = []) 
    { this.op = op; this.dest = dest; this.operands = operands; }
}

class MirBasicBlock {
    string name;
    MirInstr[] instructions;

    this(string name) { this.name = name; }
}

class MirFunction {
    string name;
    MirBasicBlock[] blocks;
    int regCounter = 0;
    int blockCounter = 0;
    Type returnType;
    bool isVarArg;
    int isVarArgAt;
    Type[] paramTypes;

    MirValue newReg(Type t) {
        return MirValue.reg(regCounter++, t);
    }

    // Cria um nome único para blocos (ex: "if_then_5")
    string uniqueBlockName(string prefix) {
        import std.conv : to;
        return prefix ~ "_" ~ to!string(blockCounter++);
    }
}

class MirGlobal
{
    string name;
    Type type;
    MirValue initVal; // Valor constante inicial (pode ser null)
    bool isPublic = true; // Para exportar símbolo

    this(string name, Type type) {
        this.name = name;
        this.type = type;
    }
}

class MirProgram {
    MirFunction[] functions;
    MirGlobal[] globals;
}
