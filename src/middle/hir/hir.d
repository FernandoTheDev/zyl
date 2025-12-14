module middle.hir.hir;

import frontend.parser.ast;
import frontend.types.type;

enum HirNodeKind
{
    Program, Function, Block,
    // Declarações
    VarDecl, AssignDecl, IndexExpr, StructDecl, UnionDecl, EnumDecl, AssignExpr,
    // Statements (Comandos)
    Store, Return, If, For, CallStmt, Version, While, Break, Continue, Defer,
    // Expressões
    IntLit, FloatLit, StringLit, BoolLit, CharLit, NullLit, ArrayLit, StructLit,
    Binary, Unary, Cast, Load, AddrOf, CallExpr,
    IndexAccess, MemberAccess, Ternary, Deref, AddrOfComplex
}

abstract class HirNode
{
    HirNodeKind kind;
    Type type; // Tipo resolvido é crucial no HIR
}

class HirProgram : HirNode
{
    HirNode[] globals;
    // Globals poderiam entrar aqui
    this() { kind = HirNodeKind.Program; }
}

class HirFunction : HirNode
{
    string name;
    HirBlock body;
    Type returnType;
    string[] argNames;
    bool isVarArg;
    int isVarArgAt;
    Type[] argTypes;
    this() { kind = HirNodeKind.Function; }
}

class HirBlock : HirNode
{
    HirNode[] stmts;
    this() { kind = HirNodeKind.Block; }
}

class HirVarDecl : HirNode
{
    string name;
    HirNode initValue; 
    bool isGlobal;
    this() { kind = HirNodeKind.VarDecl; }
}

class HirStore : HirNode
{
    HirNode ptr;   // L-Value (Endereço)
    HirNode value; // R-Value (Valor)
    this() { kind = HirNodeKind.Store; }
}

class HirReturn : HirNode
{
    HirNode value;
    this() { kind = HirNodeKind.Return; }
}

class HirIf : HirNode
{
    HirNode condition;
    HirBlock thenBlock;
    HirBlock elseBlock;
    this() { kind = HirNodeKind.If; }
}

class HirWhile : HirNode
{
    HirNode condition; // Expressão bool
    HirBlock body;
    this() { kind = HirNodeKind.While; }
}

class HirFor : HirNode
{
    HirNode init_;      // Geralmente VarDecl ou Store
    HirNode condition; // Expressão bool
    HirNode increment; // Expressão/Store
    HirBlock body;
    this() { kind = HirNodeKind.For; }
}

class HirBreak : HirNode
{
    this() { kind = HirNodeKind.Break; }
}

class HirContinue : HirNode
{
    this() { kind = HirNodeKind.Continue; }
}

class HirCallStmt : HirNode
{
    HirCallExpr call;
    this() { kind = HirNodeKind.CallStmt; }
}

class HirIntLit : HirNode
{
    long value;
    this(long v, Type t) { kind = HirNodeKind.IntLit; value = v; type = t; }
}

class HirFloatLit : HirNode
{
    double value;
    this(double v, Type t) { kind = HirNodeKind.FloatLit; value = v; type = t; }
}

class HirBoolLit : HirNode
{
    bool value;
    this(bool v, Type t) { kind = HirNodeKind.BoolLit; value = v; type = t; }
}

class HirCharLit : HirNode
{
    char value;
    this(char v, Type t) { kind = HirNodeKind.CharLit; value = v; type = t; }
}

class HirStringLit : HirNode
{
    string value;
    this(string v, Type t) { kind = HirNodeKind.StringLit; value = v; type = t; }
}

class HirNullLit : HirNode
{
    this(Type t) { kind = HirNodeKind.NullLit; type = t; }
}

class HirArrayLit : HirNode
{
    HirNode[] elements;
    this(Type t) { kind = HirNodeKind.ArrayLit; type = t; }
}

class HirBinary : HirNode
{
    string op;
    HirNode left, right;
    this() { kind = HirNodeKind.Binary; }
}

class HirUnary : HirNode
{
    string op;
    HirNode operand;
    this() { kind = HirNodeKind.Unary; }
}

class HirTernary : HirNode
{
    HirNode condition;
    HirNode trueExpr;
    HirNode falseExpr;
    this() { kind = HirNodeKind.Ternary; }
}

class HirCast : HirNode
{
    HirNode value;
    Type targetType;
    this() { kind = HirNodeKind.Cast; type = targetType; }
}

// Acesso a Array: ptr[index] -> Na memória é *(ptr + index * size)
class HirIndexAccess : HirNode
{
    HirNode target; // O array/ponteiro
    HirNode index;  // O índice
    this() { kind = HirNodeKind.IndexAccess; }
}

// Acesso a Membro: struct.membro -> Na memória é *(ptr + offset)
class HirMemberAccess : HirNode
{
    HirNode target; // A struct
    string memberName;
    int memberOffset; // Calculado durante o lowering (usando info de tipo)
    this() { kind = HirNodeKind.MemberAccess; }
}

class HirLoad : HirNode
{
    HirNode ptr; 
    string varName; // Debug
    this() { kind = HirNodeKind.Load; }
}

class HirAddrOf : HirNode
{
    HirNode target; 
    string varName; // Debug
    this() { kind = HirNodeKind.AddrOf; }
}

class HirCallExpr : HirNode
{
    string funcName;
    bool isVarArg;
    int isVarArgAt;
    bool isExternalCall;
    HirNode[] args;
    this() { kind = HirNodeKind.CallExpr; }
}

class HirDeref : HirNode
{
    HirNode ptr;  // A expressão que avalia o ponteiro
    
    this() {
        this.kind = HirNodeKind.Deref;
    }
}

// Representa: nomes[0]
class HirIndexExpr : HirNode
{
    HirNode target; // O array (ex: 'names')
    HirNode index;  // O índice (ex: '0')
    
    this() { kind = HirNodeKind.IndexExpr; }
}

// Representa: x = y, x += y, ...
class HirAssignDecl : HirNode
{
    HirNode target; // L-Value (onde salvar)
    HirNode value;  // R-Value (o valor)
    string op;
    
    this() { kind = HirNodeKind.AssignDecl; }
}

class HirVersion : HirNode
{
    HirBlock block;
    this(HirBlock block) { kind = HirNodeKind.Version; this.block = block; }
}

class HirStructDecl : HirNode
{
    string name;
    string[] fieldNames;
    Type[] fieldTypes;
    int[] fieldOffsets;  // Offset de cada campo na memória
    int totalSize;       // Tamanho total da struct
    
    this() { kind = HirNodeKind.StructDecl; }
}

class HirStructLit : HirNode
{
    string structName;
    HirNode[] fieldValues;  // Valores na ordem dos campos
    bool isConstructorCall;
    
    this() { kind = HirNodeKind.StructLit; }
}

// Representa &(expressão_complexa) como array[i], obj.field
class HirAddrOfComplex : HirNode
{
    HirNode expr;  // A expressão cujo endereço queremos
    
    this(HirNode expr, Type type)
    {
        this.kind = HirNodeKind.AddrOfComplex;
        this.expr = expr;
        this.type = type;
    }
}

class HirUnionDecl : HirNode
{
    string name;
    string[] fieldNames;
    Type[] fieldTypes;
    int[] fieldOffsets;  // Offset de cada campo na memória
    int totalSize;       // Tamanho total da union
    
    this() { kind = HirNodeKind.UnionDecl; }
}

class HirEnumDecl : HirNode
{
    string name;
    string[] fieldNames;
    Type[] fieldTypes;
    int[] fieldOffsets;  // Offset de cada campo na memória
    int totalSize;       // Tamanho total da enum
    
    this() { kind = HirNodeKind.EnumDecl; }
}

class HirDefer : HirNode
{
    HirNode value;
    this(HirNode value) { kind = HirNodeKind.Defer; this.value = value; }
}

class HirAssignExpr : HirNode {
    HirAssignDecl assign;   
    this() { kind = HirNodeKind.AssignExpr; }
}
