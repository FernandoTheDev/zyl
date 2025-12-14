module frontend.parser.ast;

import frontend;

enum NodeKind
{
    Program,
    Identifier,

    IntLit,
    LongLit,
    FloatLit,
    DoubleLit,
    StringLit,
    BoolLit,
    NullLit,
    ArrayLit,
    CharLit,
    StructLit,

    FuncDecl,
    VarDecl,
    TypeDecl,
    AssignDecl,
    StructDecl,
    EnumDecl,
    UnionDecl,

    BinaryExpr,
    CallExpr,
    UnaryExpr,
    IndexExpr,
    MemberExpr,
    TernaryExpr,
    CastExpr,
    SizeOfExpr,

    BlockStmt,
    IfStmt,
    ForStmt,
    ReturnStmt,
    VersionStmt,
    WhileStmt,
    BrkOrCntStmt, // BreakOrContinueStmt
    ImportStmt,
    DeferStmt,
}

abstract class Node
{
    NodeKind kind;
    Variant value;
    TypeExpr type;
    Type resolvedType = Type.init;
    Loc loc;
    string mangledName;

    void print(ulong ident = 0, bool isLast = false);
}

class Program : Node
{
    Node[] body;
    this(Node[] body)
    {
        this.kind = NodeKind.Program;
        this.body = body;
        this.loc = loc;
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        println("├── Program", ident);
        println("│   └── Body (" ~ to!string(body.length) ~ " nodes):", ident);
        foreach (long i, Node node; body)
        {
            if (i == cast(uint)
                body.length - 1)
                node.print(ident + 8, true); // ultimo
            else
                node.print(ident + 8, false);
        }
    }
}

class VarDecl : Node
{
    string id;
    bool isConst;
    bool isGlobal;
    this(string id, TypeExpr type, Node value, bool isConst, Loc loc)
    {
        this.kind = NodeKind.VarDecl;
        this.id = id;
        this.type = type;
        this.value = value;
        this.isConst = isConst;
        this.loc = loc;
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        string prefix = isLast ? "└── " : "├── ";
        string continuation = isLast ? "    " : "│   ";

        println(prefix ~ "VarDecl: " ~ id, ident);
        println(continuation ~ "├── Type " ~ type.toStr(), ident);
        println(continuation ~ "├── Resolved type: " ~ (resolvedType is null ? "Null" : resolvedType.toStr()), ident);
        if (value.get!Node is null)
            println(continuation ~ "└── Value: Null", ident);
        else
        {
            println(continuation ~ "└── Value:", ident);
            value.get!Node.print(ident + continuation.length + 4, true);
        }
    }
}

class DoubleLit : Node
{
    this(double n, Loc loc)
    {
        this.kind = NodeKind.DoubleLit;
        this.type = new NamedTypeExpr(BaseType.Double, loc);
        this.value = n;
        this.loc = loc;
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        string prefix = isLast ? "└── " : "├── ";
        string continuation = isLast ? "    " : "│   ";

        println(prefix ~ "DoubleLit: " ~ to!string(value.get!double), ident);
        println(continuation ~ "└── Type " ~ type.toStr(), ident);
    }
}

class FloatLit : Node
{
    this(float n, Loc loc)
    {
        this.kind = NodeKind.FloatLit;
        this.type = new NamedTypeExpr(BaseType.Float, loc);
        this.value = n;
        this.loc = loc;
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        string prefix = isLast ? "└── " : "├── ";
        string continuation = isLast ? "    " : "│   ";

        println(prefix ~ "FloatLit: " ~ to!string(value.get!float), ident);
        println(continuation ~ "└── Type " ~ type.toStr(), ident);
    }
}

class LongLit : Node
{
    this(long n, Loc loc)
    {
        this.kind = NodeKind.LongLit;
        this.type = new NamedTypeExpr(BaseType.Long, loc);
        this.value = n;
        this.loc = loc;
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        string prefix = isLast ? "└── " : "├── ";
        string continuation = isLast ? "    " : "│   ";

        println(prefix ~ "IntLit: " ~ to!string(value.get!long), ident);
        println(continuation ~ "└── Type " ~ type.toStr(), ident);
    }
}

class IntLit : Node
{
    this(int n, Loc loc)
    {
        this.kind = NodeKind.IntLit;
        this.type = new NamedTypeExpr(BaseType.Int, loc);
        this.value = n;
        this.loc = loc;
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        string prefix = isLast ? "└── " : "├── ";
        string continuation = isLast ? "    " : "│   ";

        println(prefix ~ "IntLit: " ~ to!string(value.get!int), ident);
        println(continuation ~ "└── Type " ~ type.toStr(), ident);
    }
}

class StringLit : Node
{
    this(string n, Loc loc)
    {
        this.kind = NodeKind.StringLit;
        this.type = new PointerTypeExpr(new NamedTypeExpr(BaseType.Char, loc), loc);
        this.value = n;
        this.loc = loc;
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        string prefix = isLast ? "└── " : "├── ";
        string continuation = isLast ? "    " : "│   ";

        println(prefix ~ "StringLit: \"" ~ value.get!string ~ "\"", ident);
        println(continuation ~ "└── Type " ~ type.toStr(), ident);
    }
}

class CharLit : Node
{
    this(char n, Loc loc)
    {
        this.kind = NodeKind.CharLit;
        this.type = new NamedTypeExpr(BaseType.Char, loc);
        this.value = n;
        this.loc = loc;
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        string prefix = isLast ? "└── " : "├── ";
        string continuation = isLast ? "    " : "│   ";

        println(prefix ~ "CharLit: '" ~ value.get!char ~ "'", ident);
        println(continuation ~ "└── Type " ~ type.toStr(), ident);
    }
}

class BoolLit : Node
{
    this(bool n, Loc loc)
    {
        this.kind = NodeKind.BoolLit;
        this.type = new NamedTypeExpr(BaseType.Bool, loc);
        this.value = n;
        this.loc = loc;
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        string prefix = isLast ? "└── " : "├── ";
        string continuation = isLast ? "    " : "│   ";

        println(prefix ~ "BoolLit: " ~ value.get!bool ? "true" : "false", ident);
        println(continuation ~ "└── Type " ~ type.toStr(), ident);
    }
}

class CallExpr : Node
{
    Node id;
    Node[] args;
    bool isVarArg;
    int isVarArgAt;
    bool isExternalCall;

    this(Node id, Node[] args, Loc loc)
    {
        this.kind = NodeKind.CallExpr;
        this.id = id;
        this.loc = loc;
        this.type = new NamedTypeExpr(BaseType.Void, loc);
        this.args = args;
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        string prefix = isLast ? "└── " : "├── ";
        string continuation = isLast ? "    " : "│   ";

        println(prefix ~ "CallExpr: ", ident);
        id.print(ident + continuation.length + 4, true);
        println(continuation ~ "├── Type " ~ type.toStr(), ident);
        println(continuation ~ "├── Resolved type: " ~ (resolvedType is null ? "Null" : resolvedType.toStr()), ident);
        println(continuation ~ "└── Args (" ~ to!string(args.length) ~ "):", ident);

        foreach (long i, Node arg; args)
        {
            if (i == cast(uint) args.length - 1)
                arg.print(ident + continuation.length + 4, true);
            else
                arg.print(ident + continuation.length + 4, false);
        }
    }
}

class Identifier : Node
{
    this(string id, Loc loc)
    {
        this.kind = NodeKind.Identifier;
        this.type = new NamedTypeExpr(BaseType.Any, loc);
        this.value = id;
        this.loc = loc;
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        string prefix = isLast ? "└── " : "├── ";
        string continuation = isLast ? "    " : "│   ";

        println(prefix ~ "Identifier: " ~ value.get!string, ident);
        println(continuation ~ "├── Type " ~ type.toStr(), ident);
        println(continuation ~ "└── Resolved type: " ~ (resolvedType is null ? "Null" : resolvedType.toStr()), ident);
    }
}

class BinaryExpr : Node
{
    Node left, right;
    string op;
    bool usesOpBinary = false;
    bool isRight = false;
    this(Node left, Node right, string op, Loc loc)
    {
        this.kind = NodeKind.BinaryExpr;
        this.left = left;
        this.type = left.type;
        this.loc = loc;
        this.right = right;
        this.op = op;
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        string prefix = isLast ? "└── " : "├── ";
        string continuation = isLast ? "    " : "│   ";

        println(prefix ~ "BinaryExpr: (" ~ op ~ ")", ident);
        println(continuation ~ "├── Type " ~ type.toStr(), ident);
        println(continuation ~ "├── Resolved type: " ~ (resolvedType is null ? "Null" : resolvedType.toStr()), ident);
        println(continuation ~ "├── Left:", ident);

        if (left !is null)
            left.print(ident + continuation.length + 4, false);
        else
            println(continuation ~ "│   └── (Null)", ident);

        println(continuation ~ "└── Right:", ident);

        if (right !is null)
            right.print(ident + continuation.length + 4, true);
        else
            println(continuation ~ "    └── (Null)", ident);
    }
}

class NullLit : Node
{
    this(Loc loc)
    {
        this.kind = NodeKind.NullLit;
        this.type = new PointerTypeExpr(new NamedTypeExpr(BaseType.Void, loc), loc);
        this.value = null;
        this.loc = loc;
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        string prefix = isLast ? "└── " : "├── ";
        string continuation = isLast ? "    " : "│   ";

        println(prefix ~ "NullLiteral", ident);
        println(continuation ~ "└── Type " ~ type.toStr(), ident);
    }
}

class ArrayLit : Node
{
    Node[] elements;

    this(Node[] elements, Loc loc)
    {
        this.kind = NodeKind.ArrayLit;
        this.elements = elements;
        this.loc = loc;
        this.type = new ArrayTypeExpr(new NamedTypeExpr(BaseType.Any, loc), loc, elements.length);
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        string prefix = isLast ? "└── " : "├── ";
        string continuation = isLast ? "    " : "│   ";

        println(prefix ~ "ArrayLiteral (" ~ to!string(elements.length) ~ " elements)", ident);
        println(continuation ~ "├── Type " ~ type.toStr(), ident);
        println(continuation ~ "├── Resolved type: " ~ (resolvedType is null ? "Null" : resolvedType.toStr()), ident);
        println(continuation ~ "└── Elements:", ident);

        foreach (long i, Node elem; elements)
        {
            if (i == cast(uint) elements.length - 1)
                elem.print(ident + continuation.length + 4, true);
            else
                elem.print(ident + continuation.length + 4, false);
        }
    }
}

class SizeOfExpr : Node
{
    TypeExpr type_ = null;
    Type resolvedType_ = null;
    Node value;
    this(Node value = null, TypeExpr type = null, Loc loc)
    {
        this.kind = NodeKind.SizeOfExpr;
        this.type = new NamedTypeExpr(BaseType.Int, loc);
        this.value = value;
        this.type_ = type;
        this.loc = loc;
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        string prefix = isLast ? "└── " : "├── ";
        string continuation = isLast ? "    " : "│   ";

        println(prefix ~ "SizeOfExpr", ident);
        println(continuation ~ "├── Type " ~ type.toStr(), ident);
        println(continuation ~ "└── Resolved type: " ~ (resolvedType is null ? "Null" : resolvedType.toStr()), ident);
    }
}

class UnaryExpr : Node
{
    Node operand;
    string op;

    this(Node operand, TypeExpr type, string op, Loc loc)
    {
        this.kind = NodeKind.UnaryExpr;
        this.operand = operand;
        this.op = op;
        this.type = type;
        this.loc = loc;
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        string prefix = isLast ? "└── " : "├── ";
        string continuation = isLast ? "    " : "│   ";

        println(prefix ~ "UnaryExpr: (" ~ op ~ ")", ident);
        println(continuation ~ "├── Type " ~ type.toStr(), ident);
        println(continuation ~ "├── Resolved type: " ~ (resolvedType is null ? "Null" : resolvedType.toStr()), ident);
        println(continuation ~ "└── Op:", ident);

        if (operand !is null)
            operand.print(ident + continuation.length + 4, true);
        else
            println(continuation ~ "    └── (Null)", ident);
    }
}

class AssignDecl : Node
{
    Node left, right;
    string op;

    this(Node left, Node right, string op, Loc loc)
    {
        this.kind = NodeKind.AssignDecl;
        this.left = left;
        this.right = right;
        this.op = op;
        this.type = left.type;
        this.loc = loc;
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        string prefix = isLast ? "└── " : "├── ";
        string continuation = isLast ? "    " : "│   ";

        println(prefix ~ "AssignDecl: (" ~ op ~ ")", ident);
        println(continuation ~ "├── Type " ~ type.toStr(), ident);
        println(continuation ~ "├── Resolved type: " ~ (resolvedType is null ? "Null" : resolvedType.toStr()), ident);
        println(continuation ~ "├── Target:", ident);

        if (left !is null)
            left.print(ident + continuation.length + 4, false);
        else
            println(continuation ~ "│   └── (Null)", ident);

        println(continuation ~ "└── Value:", ident);

        if (right !is null)
            right.print(ident + continuation.length + 4, true);
        else
            println(continuation ~ "    └── (Null)", ident);
    }
}

class IndexExpr : Node
{
    Node target;
    Node index;

    this(Node target, Node index, Loc loc)
    {
        this.kind = NodeKind.IndexExpr;
        this.target = target;
        this.index = index;
        this.loc = loc;
        // Tipo será determinado depois (elemento do array/string)
        this.type = new NamedTypeExpr(BaseType.Any, loc);
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        string prefix = isLast ? "└── " : "├── ";
        string continuation = isLast ? "    " : "│   ";

        println(prefix ~ "IndexExpr: [ ... ]", ident);
        println(continuation ~ "├── Type " ~ type.toStr(), ident);
        println(continuation ~ "├── Resolved type: " ~ (resolvedType is null ? "Null" : resolvedType.toStr()), ident);
        println(continuation ~ "├── Target:", ident);

        if (target !is null)
            target.print(ident + continuation.length + 4, false);
        else
            println(continuation ~ "│   └── (Null)", ident);

        println(continuation ~ "└── Index:", ident);

        if (index !is null)
            index.print(ident + continuation.length + 4, true);
        else
            println(continuation ~ "    └── (Null)", ident);
    }
}

class MemberExpr : Node
{
    Node target;
    string member;

    this(Node target, string member, Loc loc)
    {
        this.kind = NodeKind.MemberExpr;
        this.target = target;
        this.member = member;
        this.loc = loc;
        this.type = new NamedTypeExpr(BaseType.Void, loc);
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        string prefix = isLast ? "└── " : "├── ";
        string continuation = isLast ? "    " : "│   ";

        println(prefix ~ "MemberExpr: ." ~ member, ident);
        println(continuation ~ "├── Type " ~ type.toStr(), ident);
        println(continuation ~ "├── Resolved type: " ~ (resolvedType is null ? "Null" : resolvedType.toStr()), ident);
        println(continuation ~ "└── Target:", ident);

        if (target !is null)
            target.print(ident + continuation.length + 4, true);
        else
            println(continuation ~ "    └── (Null)", ident);
    }
}

class TypeDecl : Node
{
    this(string id, TypeExpr type, Loc loc)
    {
        this.kind = NodeKind.TypeDecl;
        this.type = type;
        this.value = id;
        this.loc = loc;
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        string prefix = isLast ? "└── " : "├── ";
        string continuation = isLast ? "    " : "│   ";

        println(prefix ~ format("TypeDecl: (%s) ", value.get!string), ident);
        println(continuation ~ "└── Type " ~ type.toStr(), ident);
    }
}

struct FuncArgument
{
    string name;
    TypeExpr type;
    Type resolvedType;
    Node value;
    Loc loc;
    bool variadic;
}

class FuncDecl : Node
{
    string name;
    BlockStmt body;
    FuncArgument[] args;
    bool isVarArg, noMangle;
    int isVarArgAt;
    bool isExtern = true;
    
    this(string name, ref FuncArgument[] args, Node[] body, TypeExpr type, Loc loc, bool isVarArg, 
        bool isExtern = false, bool noMangle = false)
    {
        this.kind = NodeKind.FuncDecl;
        this.type = type;
        if (!isExtern)
            this.body = new BlockStmt(body, loc);
        else
            this.body = null;
        this.name = name;
        this.args = args;
        this.loc = loc;
        this.isVarArg = isVarArg;
        this.isExtern = isExtern;
        this.noMangle = noMangle;
        if (isVarArg)
            this.isVarArgAt = cast(int) args.length - 1; // ao ultimo idx
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        string prefix = isLast ? "└── " : "├── ";
        string continuation = isLast ? "    " : "│   ";

        println(prefix ~ "FuncDecl: " ~ name, ident);
        println(continuation ~ "├── Type " ~ type.toStr(), ident);
        println(continuation ~ "├── Resolved type: " ~ (resolvedType is null ? "Null" : resolvedType.toStr()), ident);
        println(continuation ~ "├── Args (" ~ to!string(args.length) ~ "):", ident);

        foreach (long i, FuncArgument arg; args)
        {
            string argPrefix = (i == cast(uint) args.length - 1) ? "└── " : "├── ";
            println(continuation ~ "│   " ~ argPrefix ~ "Arg: " ~ arg.name, ident);
            if (arg.type !is null) {
                println(continuation ~ "│   " ~ (i == cast(uint) args.length - 1 ? "    " : "│   ") ~
                        "├── Type " ~ arg.type.toStr(), ident);
                println(continuation ~ "│   " ~ (i == cast(uint) args.length - 1 ? "    " : "│   ") ~
                        "├── Resolved type: " ~ (arg.resolvedType is null ? "Null" : arg.resolvedType.toStr()), ident);
                println(continuation ~ "│   " ~ (i == cast(uint) args.length - 1 ? "    " : "│   ") ~
                        "└── Default value: " ~ (arg.value !is null ? "yes sir" : "no sir"), ident);
            }
        }

        if (body !is null) {
            println(continuation ~ "└── Body (" ~ to!string(
                    body.statements.length) ~ " nodes):", ident);
            foreach (long i, Node node; body.statements)
            {
                if (i == cast(uint)
                    body.statements.length - 1)
                    node.print(ident + continuation.length + 4, true);
                else
                    node.print(ident + continuation.length + 4, false);
            }
        }
    }
}

class BlockStmt : Node
{
    Node[] statements;

    this(Node[] statements, Loc loc)
    {
        this.kind = NodeKind.BlockStmt;
        this.statements = statements;
        this.loc = loc;
        this.type = new NamedTypeExpr(BaseType.Void, loc);
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        string prefix = isLast ? "└── " : "├── ";
        string continuation = isLast ? "    " : "│   ";

        println(prefix ~ "BlockStmt { ... }", ident);
        foreach (long i, Node stmt; statements)
        {
            bool last = (i == cast(uint) statements.length - 1);
            stmt.print(ident + continuation.length + 4, last);
        }
    }
}

class IfStmt : Node
{
    Node condition;
    Node thenBranch;
    Node elseBranch; // Pode ser null ou IfStmt sem condition

    this(Node condition, Node thenBranch, Node elseBranch, Loc loc)
    {
        this.kind = NodeKind.IfStmt;
        this.condition = condition;
        this.thenBranch = thenBranch;
        this.elseBranch = elseBranch;
        this.loc = loc;
        this.type = new NamedTypeExpr(BaseType.Void, loc);
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        string prefix = isLast ? "└── " : "├── ";
        string continuation = isLast ? "    " : "│   ";

        println(prefix ~ "IfStmt", ident);

        // } senao {
        if (condition is null)
            println(continuation ~ "├── Condition: (empty)", ident);
        else
        {
            println(continuation ~ "├── Condition:", ident);
            condition.print(ident + continuation.length + 4, false);
        }

        println(continuation ~ "├── If:", ident);
        thenBranch.print(ident + continuation.length + 4, elseBranch is null); // Se não tiver else, o then é o ultimo visualmente

        if (elseBranch !is null)
        {
            println(continuation ~ "└── Else:", ident);
            elseBranch.print(ident + continuation.length + 4, true);
        }
    }
}

class VersionStmt : Node
{
    string target = "";
    BlockStmt thenBranch;
    VersionStmt elseBranch; // Pode ser null
    BlockStmt resolvedBranch = null;

    this(string target, BlockStmt thenBranch, VersionStmt elseBranch, Loc loc)
    {
        this.kind = NodeKind.VersionStmt;
        this.target = target;
        this.thenBranch = thenBranch;
        this.elseBranch = elseBranch;
        this.loc = loc;
        this.type = new NamedTypeExpr(BaseType.Void, loc);
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        string prefix = isLast ? "└── " : "├── ";
        string continuation = isLast ? "    " : "│   ";

        println(prefix ~ "VersionStmt", ident);

        // } senao {
        if (target == "")
            println(continuation ~ "├── Target: (empty)", ident);
        else
            println(continuation ~ "├── Target: ( " ~ target ~ " )", ident);

        println(continuation ~ "├── Then:", ident);
        thenBranch.print(ident + continuation.length + 4, elseBranch is null); // Se não tiver else, o then é o ultimo visualmente

        if (elseBranch !is null)
        {
            println(continuation ~ "└── Else:", ident);
            elseBranch.print(ident + continuation.length + 4, true);
        }
    }
}

class ForStmt : Node
{
    Node init_; // Pode ser VarDecl ou Expr (ou null)
    Node condition; // Pode ser null
    Node increment; // Pode ser Expr (ou null)
    Node body;

    this(Node init, Node condition, Node increment, Node[] body, Loc loc)
    {
        this.kind = NodeKind.ForStmt;
        this.init_ = init;
        this.condition = condition;
        this.increment = increment;
        this.body = new BlockStmt(body, loc);
        this.loc = loc;
        this.type = new NamedTypeExpr(BaseType.Void, loc);
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        string prefix = isLast ? "└── " : "├── ";
        string continuation = isLast ? "    " : "│   ";

        println(prefix ~ "ForStmt (C-Style)", ident);

        println(continuation ~ "├── Init:", ident);
        if (init_ !is null)
            init_.print(ident + continuation.length + 4, false);
        else
            println(continuation ~ "│   └── (empty)", ident);

        println(continuation ~ "├── Condition:", ident);
        if (condition !is null)
            condition.print(ident + continuation.length + 4, false);
        else
            println(continuation ~ "│   └── (empty/true)", ident);

        println(continuation ~ "├── Incremento:", ident);
        if (increment !is null)
            increment.print(ident + continuation.length + 4, false);
        else
            println(continuation ~ "│   └── (empty)", ident);

        println(continuation ~ "└── Body:", ident);
        body.print(ident + continuation.length + 4, true);
    }
}

class ReturnStmt : Node
{
    Node value; // Pode ser null (return void)

    this(Node value, Loc loc)
    {
        this.kind = NodeKind.ReturnStmt;
        this.value = value;
        this.loc = loc;
        this.type = new NamedTypeExpr(BaseType.Void, loc); // Statement não tem tipo, ou é Bottom
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        string prefix = isLast ? "└── " : "├── ";
        string continuation = isLast ? "    " : "│   ";

        println(prefix ~ "ReturnStmt", ident);
        if (value !is null)
        {
            println(continuation ~ "└── Value:", ident);
            value.print(ident + continuation.length + 4, true);
        }
        else
            println(continuation ~ "└── (void)", ident);
    }
}

class TernaryExpr : Node
{
    Node condition;
    Node trueExpr;
    Node falseExpr;

    this(Node condition, Node trueExpr, Node falseExpr, Loc loc)
    {
        this.kind = NodeKind.TernaryExpr;
        this.condition = condition;
        this.trueExpr = trueExpr;
        this.falseExpr = falseExpr;
        this.loc = loc;
        this.type = new NamedTypeExpr(BaseType.Any, loc);
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        string prefix = isLast ? "└── " : "├── ";
        string continuation = isLast ? "    " : "│   ";

        println(prefix ~ "TernaryExpr (? :)", ident);

        println(continuation ~ "├── Condition:", ident);
        condition.print(ident + continuation.length + 4, false);

        if (trueExpr !is null)
        {
            println(continuation ~ "├── Case true:", ident);
            trueExpr.print(ident + continuation.length + 4, false);
        }
        else
            println(continuation ~ "├── Case true: (Null)", ident);

        println(continuation ~ "└── Case false:", ident);
        falseExpr.print(ident + continuation.length + 4, true);
    }
}

class CastExpr : Node
{
    Node from;
    TypeExpr target;

    this(TypeExpr target, Node from, Loc loc)
    {
        this.kind = NodeKind.CastExpr;
        this.from = from;
        this.target = target;
        this.loc = loc;
        this.type = target;
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        string prefix = isLast ? "└── " : "├── ";
        string continuation = isLast ? "    " : "│   ";

        println(prefix ~ "CastExpr", ident);
        println(continuation ~ "├── Target: " ~ target.toStr(), ident);
        println(continuation ~ "├── Resolved type: " ~ (resolvedType is null ? "Null" : resolvedType.toStr()), ident);
        println(continuation ~ "└── Value:", ident);
        from.print(ident + continuation.length + 4, true);
    }
}

struct StructField
{
    string name;
    TypeExpr type;
    Type resolvedType;
    Node defaultValue; // Pode ser null
    Loc loc;
}

struct StructMethod
{
    FuncDecl funcDecl;
    bool isConstructor; // true se for this(...)
    Loc loc;
}

class StructDecl : Node
{
    string name;
    StructField[] fields;
    StructMethod[][string] methods;
    bool noMangle;

    this(string name, StructField[] fields, StructMethod[][string] methods, Loc loc, bool noMangle = false)
    {
        this.kind = NodeKind.StructDecl;
        this.name = name;
        this.fields = fields;
        this.methods = methods;
        this.loc = loc;
        this.noMangle = noMangle;
        this.type = new NamedTypeExpr(BaseType.Void, loc);
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        string prefix = isLast ? "└── " : "├── ";
        string continuation = isLast ? "    " : "│   ";

        println(prefix ~ "StructDecl: " ~ name, ident);
        
        // Imprimir campos
        if (fields.length > 0)
        {
            println(continuation ~ "├── Fields (" ~ to!string(fields.length) ~ "):", ident);
            foreach (long i, StructField field; fields)
            {
                string fieldPrefix = (i == cast(uint) fields.length - 1 && methods.length == 0) ? "└── " : "├── ";
                println(continuation ~ "│   " ~ fieldPrefix ~ field.name ~ ": " ~ field.type.toStr(), ident);
                if (field.defaultValue !is null)
                {
                    string contField = (i == cast(uint) fields.length - 1 && methods.length == 0) ? "    " : "│   ";
                    println(continuation ~ "│   " ~ contField ~ "└── Default:", ident);
                    field.defaultValue.print(ident + continuation.length + 8 + contField.length, true);
                }
            }
        }

        // Imprimir métodos
        if (methods.length > 0)
        {
            println(continuation ~ "└── Methods (" ~ to!string(methods.length) ~ "):", ident);
            // foreach (long i, StructMethod method; methods)
            // {
            //     bool isLastMethod = (i == cast(uint) methods.length - 1);
            //     method.funcDecl.print(ident + continuation.length + 4, isLastMethod);
            // }
        }
    }
}

struct StructFieldInit
{
    string name;  // vazio se for posicional
    Node value;
    uint position; // usado para inicialização posicional
    Loc loc;
}

class StructLit : Node
{
    string structName;
    StructFieldInit[] fieldInits;
    bool isPositional; // true para Test{"John", 17}, false para Test{.name="John"}
    bool isConstructorCall;

    this(string structName, StructFieldInit[] fieldInits, bool isPositional, Loc loc, 
        bool isConstructorCall = false)
    {
        this.kind = NodeKind.StructLit;
        this.structName = structName;
        this.fieldInits = fieldInits;
        this.isPositional = isPositional;
        this.loc = loc;
        this.isConstructorCall = isConstructorCall;
        this.type = new StructTypeExpr(structName, loc); // Será resolvido depois
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        string prefix = isLast ? "└── " : "├── ";
        string continuation = isLast ? "    " : "│   ";

        string initType = isPositional ? "positional" : "named";
        println(prefix ~ "StructLit: " ~ structName ~ " (" ~ initType ~ ")", ident);
        println(continuation ~ "├── Type " ~ type.toStr(), ident);
        println(continuation ~ "├── Resolved type: " ~ (resolvedType is null ? "Null" : resolvedType.toStr()), ident);
        
        if (fieldInits.length > 0)
        {
            println(continuation ~ "└── Fields (" ~ to!string(fieldInits.length) ~ "):", ident);
            foreach (long i, StructFieldInit field; fieldInits)
            {
                bool last = (i == cast(uint) fieldInits.length - 1);
                string fieldPrefix = last ? "└── " : "├── ";
                string fieldCont = last ? "    " : "│   ";
                
                if (isPositional)
                    println(continuation ~ "    " ~ fieldPrefix ~ "[" ~ to!string(i) ~ "]:", ident);
                else
                    println(continuation ~ "    " ~ fieldPrefix ~ "." ~ field.name ~ ":", ident);
                
                if (field.value !is null)
                    field.value.print(ident + continuation.length + 8 + fieldCont.length, true);
                else
                    println(continuation ~ "    " ~ fieldCont ~ "└── (null)", ident);
            }
        }
        else
        {
            println(continuation ~ "└── Fields: (empty)", ident);
        }
    }
}

class WhileStmt : Node
{
    Node condition;
    BlockStmt body;
    this(Node condition, Node[] body, Loc loc)
    {
        this.kind = NodeKind.WhileStmt;
        this.condition = condition;
        this.body = new BlockStmt(body, loc);
        this.loc = loc;
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        // ...
    }
}

class BrkOrCntStmt : Node
{
    bool isBreak = false;
    this(bool isBreak, Loc loc)
    {
        this.kind = NodeKind.BrkOrCntStmt;
        this.isBreak = isBreak;
        this.loc = loc;
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        // ...
    }
}

class ImportStmt : Node
{
    string modulePath;      // caminho completo: "std/libc/mem"
    string[] symbols;       // símbolos selecionados: ["malloc", "free"]
    string aliasname = "";  // alias do namespace: "mem"
    
    this(Loc loc, string[] symbols = [], string aliasname = "")
    {
        this.kind = NodeKind.ImportStmt;
        this.loc = loc;
        this.symbols = symbols;
        this.aliasname = aliasname;
    }

    ImportStmt setModulePath(Node file)
    {
        this.value = file;
        this.modulePath = getFileNameFromImport(file);
        return this;
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        string prefix = isLast ? "└── " : "├── ";
        string continuation = isLast ? "    " : "│   ";

        println(prefix ~ "ImportStmt", ident);
        println(continuation ~ "├── Path: " ~ modulePath, ident);
        if (symbols.length > 0)
            println(continuation ~ "├── Symbols: [" ~ symbols.join(", ") ~ "]", ident);
        if (aliasname != "")
            println(continuation ~ "└── Alias: " ~ aliasname, ident);
    }

    string getFileNameFromImport(string str)
    {
        return str;
    }
    
    private string getFileNameFromImport(Node node)
    {
        if (node.kind == NodeKind.StringLit || node.kind == NodeKind.Identifier)
            return node.value.get!string;

        if (node.kind == NodeKind.MemberExpr)
        {
            MemberExpr mce = cast(MemberExpr) node;
            return getFileNameFromImport(mce.target) ~ "/" ~ getFileNameFromImport(mce.member);
        }
        writeln("Invalid import expression.", node.loc);
        return "";
    }
}

class DeferStmt : Node
{
    Node stmt;

    this(Node stmt)
    {
        this.kind = NodeKind.DeferStmt;
        this.stmt = stmt;
        this.loc = stmt.loc;
        this.type = new NamedTypeExpr(BaseType.Void, stmt.loc);
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        string prefix = isLast ? "└── " : "├── ";
        string continuation = isLast ? "    " : "│   ";

        println(prefix ~ "DeferStmt", ident);
        println(continuation ~ "└── Deferring:", ident);
        stmt.print(ident + continuation.length + 4, true);
    }
}

class EnumDecl : Node
{
    string name;
    // Maps member name to its integer value (e.g., "RED" -> 0)
    int[string] members;
    bool noMangle;

    this(string name, int[string] members, Loc loc, bool noMangle = false)
    {
        this.kind = NodeKind.EnumDecl;
        this.name = name;
        this.members = members;
        this.loc = loc;
        this.noMangle = noMangle;
        this.type = new NamedTypeExpr(BaseType.Void, loc); // Declaration itself has no type or Void
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        string prefix = isLast ? "└── " : "├── ";
        string continuation = isLast ? "    " : "│   ";

        println(prefix ~ "EnumDecl: " ~ name, ident);
        println(continuation ~ "└── Members:", ident);
        
        string[] keys = members.keys;
        foreach (long i, string key; keys)
        {
            string memPrefix = (i == cast(uint) keys.length - 1) ? "└── " : "├── ";
            println(continuation ~ "    " ~ memPrefix ~ key ~ " = " ~ to!string(members[key]), ident);
        }
    }
}

class UnionDecl : Node
{
    string name;
    StructField[] fields; // We can reuse StructField here as it holds name and type
    bool noMangle;

    this(string name, StructField[] fields, Loc loc, bool noMangle = false)
    {
        this.kind = NodeKind.UnionDecl;
        this.name = name;
        this.fields = fields;
        this.loc = loc;
        this.noMangle = noMangle;
        this.type = new NamedTypeExpr(BaseType.Void, loc);
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        string prefix = isLast ? "└── " : "├── ";
        string continuation = isLast ? "    " : "│   ";

        println(prefix ~ "UnionDecl: " ~ name, ident);
        
        if (fields.length > 0)
        {
            println(continuation ~ "└── Fields (" ~ to!string(fields.length) ~ "):", ident);
            foreach (long i, StructField field; fields)
            {
                string fieldPrefix = (i == cast(uint) fields.length - 1) ? "└── " : "├── ";
                println(continuation ~ "    " ~ fieldPrefix ~ field.name ~ ": " ~ field.type.toStr(), ident);
            }
        }
        else
        {
            println(continuation ~ "└── Fields: (empty)", ident);
        }
    }
}

private void println(string message, ulong ident = 0)
{
    writeln(" ".replicate(ident), message);
}

private void print(string message, ulong ident = 0)
{
    write(" ".replicate(ident), message);
}
