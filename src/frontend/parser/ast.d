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
    ForEachStmt,
    ReturnStmt,
    VersionStmt,
    WhileStmt,
    BrkOrCntStmt, // BreakOrContinueStmt
    ImportStmt,
    DeferStmt,
    SwitchStmt,
    CaseStmt,
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
    abstract Node clone();
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

    override Node clone()
    {
        auto cloned = new Program([]);
        cloned.kind = this.kind;
        cloned.type = this.type ? cast(TypeExpr) this.type.clone() : null;
        cloned.loc = this.loc;
        cloned.body = this.body.map!(n => n.clone()).array;
        return cloned;
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

    override Node clone()
    {
        auto cloned = new VarDecl(this.id, this.type ? cast(TypeExpr) this.type.clone() : null,
                                  this.value.get!Node ? this.value.get!Node.clone() : null,
                                  this.isConst, this.loc);
        cloned.kind = this.kind;
        cloned.isGlobal = this.isGlobal;
        return cloned;
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

    override Node clone()
    {
        auto cloned = new DoubleLit(this.value.get!double, this.loc);
        cloned.kind = this.kind;
        cloned.type = this.type ? cast(TypeExpr) this.type.clone() : null;
        cloned.resolvedType = this.resolvedType;
        cloned.mangledName = this.mangledName;
        return cloned;
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

    override Node clone()
    {
        auto cloned = new FloatLit(this.value.get!float, this.loc);
        cloned.kind = this.kind;
        cloned.type = this.type ? cast(TypeExpr) this.type.clone() : null;
        cloned.resolvedType = this.resolvedType;
        cloned.mangledName = this.mangledName;
        return cloned;
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

    override Node clone()
    {
        auto cloned = new LongLit(this.value.get!long, this.loc);
        cloned.kind = this.kind;
        cloned.type = this.type ? cast(TypeExpr) this.type.clone() : null;
        cloned.resolvedType = this.resolvedType;
        cloned.mangledName = this.mangledName;
        return cloned;
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

    override Node clone()
    {
        auto cloned = new IntLit(this.value.get!int, this.loc);
        cloned.kind = this.kind;
        cloned.type = this.type ? cast(TypeExpr) this.type.clone() : null;
        cloned.resolvedType = this.resolvedType;
        cloned.mangledName = this.mangledName;
        return cloned;
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

    override Node clone()
    {
        auto cloned = new StringLit(this.value.get!string, this.loc);
        cloned.kind = this.kind;
        cloned.type = this.type ? cast(TypeExpr) this.type.clone() : null;
        cloned.resolvedType = this.resolvedType;
        cloned.mangledName = this.mangledName;
        return cloned;
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

    override Node clone()
    {
        auto cloned = new CharLit(this.value.get!char, this.loc);
        cloned.kind = this.kind;
        cloned.type = this.type ? cast(TypeExpr) this.type.clone() : null;
        cloned.resolvedType = this.resolvedType;
        cloned.mangledName = this.mangledName;
        return cloned;
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

        println(prefix ~ "BoolLit: " ~ (value.get!bool ? "true" : "false"), ident);
        println(continuation ~ "└── Type " ~ type.toStr(), ident);
    }

    override Node clone()
    {
        auto cloned = new BoolLit(this.value.get!bool, this.loc);
        cloned.kind = this.kind;
        cloned.type = this.type ? cast(TypeExpr) this.type.clone() : null;
        cloned.resolvedType = this.resolvedType;
        cloned.mangledName = this.mangledName;
        return cloned;
    }
}

class CallExpr : Node
{
    Node id;
    Node[] args;
    int isVarArgAt;
    bool isExternalCall, isIndirectCall, isRef, isTemplate, isVarArg;
    TypeExpr[] templateType = [];
    FunctionType refType;

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

    override Node clone()
    {
        auto cloned = new CallExpr(this.id ? this.id.clone() : null,
                                   this.args.map!(a => a.clone()).array,
                                   this.loc);
        cloned.kind = this.kind;
        cloned.type = this.type ? cast(TypeExpr) this.type.clone() : null;
        cloned.isVarArgAt = this.isVarArgAt;
        cloned.isExternalCall = this.isExternalCall;
        cloned.isIndirectCall = this.isIndirectCall;
        cloned.isRef = this.isRef;
        cloned.isTemplate = this.isTemplate;
        cloned.isVarArg = this.isVarArg;
        cloned.templateType = this.templateType.map!(t => t ? cast(TypeExpr) t.clone() : null).array;
        cloned.refType = this.refType ? cast(FunctionType) this.refType.clone() : null;
        return cloned;
    }
}

class Identifier : Node
{
    bool isFunctionReference;
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

    override Node clone()
    {
        auto newIdent = new Identifier(value.get!string, loc);
        return newIdent;
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

    override Node clone()
    {
        auto cloned = new BinaryExpr(this.left ? this.left.clone() : null,
                                     this.right ? this.right.clone() : null,
                                     this.op, this.loc);
        cloned.kind = this.kind;
        cloned.type = this.type ? cast(TypeExpr) this.type.clone() : null;
        cloned.usesOpBinary = this.usesOpBinary;
        cloned.isRight = this.isRight;
        return cloned;
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

    override Node clone()
    {
        auto cloned = new NullLit(this.loc);
        cloned.kind = this.kind;
        cloned.value = this.value;
        cloned.type = this.type ? cast(TypeExpr) this.type.clone() : null;
        cloned.resolvedType = this.resolvedType;
        cloned.mangledName = this.mangledName;
        return cloned;
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

    override Node clone()
    {
        auto cloned = new ArrayLit(this.elements.map!(e => e.clone()).array, this.loc);
        cloned.kind = this.kind;
        cloned.type = this.type ? cast(TypeExpr) this.type.clone() : null;
        return cloned;
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

    override Node clone()
    {
        auto cloned = new SizeOfExpr(this.value ? cast(TypeExpr) this.value.clone() : null,
                                     this.type_ ? cast(TypeExpr) this.type_.clone() : null,
                                     this.loc);
        cloned.kind = this.kind;
        cloned.type = this.type ? cast(TypeExpr) this.type.clone() : null;
        return cloned;
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

    override Node clone()
    {
        auto cloned = new UnaryExpr(this.operand ? this.operand.clone() : null,
                                    this.type ? cast(TypeExpr) this.type.clone() : null,
                                    this.op, this.loc);
        cloned.kind = this.kind;
        cloned.type = this.type ? cast(TypeExpr) this.type.clone() : null;
        return cloned;
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

    override Node clone()
    {
        auto cloned = new AssignDecl(this.left ? this.left.clone() : null,
                                     this.right ? this.right.clone() : null,
                                     this.op, this.loc);
        cloned.kind = this.kind;
        cloned.type = this.type ? cast(TypeExpr) this.type.clone() : null;
        return cloned;
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

    override Node clone()
    {
        auto cloned = new IndexExpr(this.target ? this.target.clone() : null,
                                    this.index ? this.index.clone() : null,
                                    this.loc);
        cloned.kind = this.kind;
        cloned.type = this.type ? cast(TypeExpr) this.type.clone() : null;
        return cloned;
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

    override Node clone()
    {
        auto cloned = new MemberExpr(this.target ? this.target.clone() : null,
                                     this.member, this.loc);
        cloned.kind = this.kind;
        cloned.type = this.type ? cast(TypeExpr) this.type.clone() : null;
        return cloned;
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

    override Node clone()
    {
        auto cloned = new TypeDecl(this.value.get!string,
                                   this.type ? cast(TypeExpr) this.type.clone() : null,
                                   this.loc);
        cloned.kind = this.kind;
        cloned.value = Variant(this.value.get!Node.clone());
        return cloned;
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

    FuncArgument clone()
    {
        return FuncArgument(this.name,
                           this.type ? cast(TypeExpr) this.type.clone() : null,
                           this.resolvedType,
                           this.value ? this.value.clone() : null,
                           this.loc,
                           this.variadic);
    }
}

class FuncDecl : Node
{
    string name;
    BlockStmt body;
    FuncArgument[] args;
    bool isVarArg, noMangle;
    int isVarArgAt;
    bool isExtern = true;
    bool isTemplate = false;
    TypeExpr[] templateType = [];
    
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

    override Node clone()
    {
        FuncArgument[] clonedArgs;
        foreach (arg; args)
            clonedArgs ~= cast(FuncArgument) arg.clone();

        Node[] clonedBody;
        foreach (Node n; body.statements)
            clonedBody ~= n.clone();

        TypeExpr[] clonedTemplateTypes;
        foreach (tExpr; templateType)
            clonedTemplateTypes ~= cast(TypeExpr) tExpr.clone();

        auto newFunc = new FuncDecl(
            name,
            clonedArgs,
            clonedBody,
            cast(TypeExpr) type.clone(),
            loc,
            isExtern,
            noMangle,
            isVarArg
        );

        newFunc.isTemplate = isTemplate;
        newFunc.templateType = clonedTemplateTypes;
        
        return newFunc;
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

    override Node clone()
    {
        auto cloned = new BlockStmt(this.statements.map!(s => s.clone()).array, this.loc);
        cloned.kind = this.kind;
        cloned.type = this.type ? cast(TypeExpr) this.type.clone() : null;
        return cloned;
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

    override Node clone()
    {
        auto cloned = new IfStmt(this.condition ? this.condition.clone() : null,
                                 this.thenBranch ? this.thenBranch.clone() : null,
                                 this.elseBranch ? this.elseBranch.clone() : null,
                                 this.loc);
        cloned.kind = this.kind;
        cloned.type = this.type ? cast(TypeExpr) this.type.clone() : null;
        return cloned;
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

    override Node clone()
    {
        auto cloned = new VersionStmt(this.target,
                                      this.thenBranch ? cast(BlockStmt) this.thenBranch.clone() : null,
                                      this.elseBranch ? cast(VersionStmt) this.elseBranch.clone() : null,
                                      this.loc);
        cloned.kind = this.kind;
        cloned.type = this.type ? cast(TypeExpr) this.type.clone() : null;
        cloned.resolvedBranch = this.resolvedBranch ? cast(BlockStmt) this.resolvedBranch.clone() : null;
        return cloned;
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

    override Node clone()
    {
        auto cloned = new ForStmt(this.init_ ? this.init_.clone() : null,
                                  this.condition ? this.condition.clone() : null,
                                  this.increment ? this.increment.clone() : null,
                                  null, this.loc);
        cloned.kind = this.kind;
        cloned.type = this.type ? cast(TypeExpr) this.type.clone() : null;
        cloned.mangledName = this.mangledName;
        cloned.body = this.body ? cast(BlockStmt) this.body.clone() : null;
        return cloned;
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

    override Node clone()
    {
        auto cloned = new ReturnStmt(this.value ? this.value.clone() : null, this.loc);
        cloned.kind = this.kind;
        cloned.type = this.type ? cast(TypeExpr) this.type.clone() : null;
        return cloned;
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

    override Node clone()
    {
        auto cloned = new TernaryExpr(this.condition ? this.condition.clone() : null,
                                      this.trueExpr ? this.trueExpr.clone() : null,
                                      this.falseExpr ? this.falseExpr.clone() : null,
                                      this.loc);
        cloned.kind = this.kind;
        cloned.type = this.type ? cast(TypeExpr) this.type.clone() : null;
        return cloned;
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
        println(continuation ~ "├── Target: " ~ (target is null ? "null" : target.toStr()), ident);
        println(continuation ~ "├── Resolved type: " ~ (resolvedType is null ? "Null" : resolvedType.toStr()), ident);
        println(continuation ~ "└── Value:", ident);
        from.print(ident + continuation.length + 4, true);
    }

    override Node clone()
    {
        return new CastExpr(
            target ? cast(TypeExpr) target.clone() : null,
            from ? from.clone() : null,
            loc
    )   ;
    }
}

struct StructField
{
    string name;
    TypeExpr type;
    Type resolvedType;
    Node defaultValue; // Pode ser null
    Loc loc;

    StructField clone()
    {
        return StructField(this.name,
                          this.type ? cast(TypeExpr) this.type.clone() : null,
                          this.resolvedType,
                          this.defaultValue ? this.defaultValue.clone() : null,
                          this.loc);
    }
}

struct StructMethod
{
    FuncDecl funcDecl;
    bool isConstructor;
    Loc loc;

    StructMethod clone()
    {
        return StructMethod(cast(FuncDecl) this.funcDecl.clone(),
                           this.isConstructor,
                           this.loc);
    }
}

class StructDecl : Node
{
    string name;
    StructField[] fields;
    StructMethod[][string] methods;
    bool noMangle;
    bool isTemplate = false;
    TypeExpr[] templateType = [];

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

        if (methods.length > 0)
        {
            println(continuation ~ "└── Methods (" ~ to!string(methods.length) ~ "):", ident);
            foreach (mtds; methods)
            {
                foreach (long i, StructMethod method; mtds)
                {
                    bool isLastMethod = (i == cast(uint) methods.length - 1);
                    method.funcDecl.print(ident + continuation.length + 4, isLastMethod);
                }
            }
        }
    }

    override Node clone()
    {
        StructField[] clonedFields = this.fields.map!(f => f.clone()).array;
        
        StructMethod[][string] clonedMethods;
        foreach (key, methodArray; this.methods)
        {
            StructMethod[] newArray = methodArray.map!(m => m.clone()).array;
            clonedMethods[key] = newArray;
        }
        
        auto cloned = new StructDecl(this.name, clonedFields, clonedMethods, this.loc, this.noMangle);
        cloned.kind = this.kind;
        cloned.type = this.type ? cast(TypeExpr) this.type.clone() : null;
        return cloned;
    }
}

struct StructFieldInit
{
    string name;  // vazio se for posicional
    Node value;
    uint position; // usado para inicialização posicional
    Loc loc;

    StructFieldInit clone()
    {
        return StructFieldInit(this.name,
                              this.value ? this.value.clone() : null,
                              this.position,
                              this.loc);
    }
}

class StructLit : Node
{
    string structName;
    StructFieldInit[] fieldInits;
    bool isPositional; // true para Test{"John", 17}, false para Test{.name="John"}
    bool isConstructorCall;
    bool isTemplate = false;
    TypeExpr[] templateType = [];

    this(string structName, StructFieldInit[] fieldInits, bool isPositional, Loc loc, 
        bool isConstructorCall = false, TypeExpr[] templateType = [])
    {
        this.kind = NodeKind.StructLit;
        this.structName = structName;
        this.fieldInits = fieldInits;
        this.isPositional = isPositional;
        this.loc = loc;
        this.isConstructorCall = isConstructorCall;
        this.templateType = templateType;
        if (templateType.length > 0)
            this.isTemplate = true;
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

    override Node clone()
    {
        StructFieldInit[] clonedInits = this.fieldInits.map!(f => f.clone()).array;
        auto cloned = new StructLit(this.structName, clonedInits, this.isPositional, this.loc, this.isConstructorCall);
        cloned.kind = this.kind;
        cloned.type = this.type ? cast(TypeExpr) this.type.clone() : null;
        return cloned;
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

    override Node clone()
    {
        auto cloned = new WhileStmt(this.condition ? this.condition.clone() : null, null, this.loc);
        cloned.kind = this.kind;
        cloned.type = this.type ? cast(TypeExpr) this.type.clone() : null;
        cloned.body = this.body ? cast(BlockStmt) this.body.clone() : null;
        return cloned;
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

    override Node clone()
    {
        auto cloned = new BrkOrCntStmt(this.isBreak, this.loc);
        cloned.kind = this.kind;
        cloned.type = this.type ? cast(TypeExpr) this.type.clone() : null;
        return cloned;
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

    override Node clone()
    {
        auto cloned = new ImportStmt(this.loc, this.symbols.dup, this.aliasname);
        cloned.kind = this.kind;
        cloned.type = this.type ? cast(TypeExpr) this.type.clone() : null;
        cloned.modulePath = this.modulePath;
        return cloned;
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

    override Node clone()
    {
        auto cloned = new DeferStmt(this.stmt ? this.stmt.clone() : null);
        cloned.kind = this.kind;
        cloned.type = this.type ? cast(TypeExpr) this.type.clone() : null;
        return cloned;
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

    override Node clone()
    {
        auto cloned = new EnumDecl(this.name, this.members.dup, this.loc, this.noMangle);
        cloned.kind = this.kind;
        cloned.type = this.type ? cast(TypeExpr) this.type.clone() : null;
        return cloned;
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

    override Node clone()
    {
        StructField[] clonedFields = this.fields.map!(f => f.clone()).array;
        auto cloned = new UnionDecl(this.name, clonedFields, this.loc, this.noMangle);
        cloned.kind = this.kind;
        cloned.type = this.type ? cast(TypeExpr) this.type.clone() : null;
        return cloned;
    }
}

class ForEachStmt : Node
{
    string iterVar;
    Node iterable;
    BlockStmt body;
    TypeExpr iterVarType;
    
    this(string iterVar, Node iterable, Node[] body, Loc loc, TypeExpr iterVarType = null)
    {
        this.kind = NodeKind.ForEachStmt;
        this.iterVar = iterVar;
        this.iterable = iterable;
        this.body = new BlockStmt(body, loc);
        this.iterVarType = iterVarType;
        this.loc = loc;
        this.type = new NamedTypeExpr(BaseType.Void, loc);
    }

    override void print(ulong ident = 0, bool isLast = false)
    {
        string prefix = isLast ? "└── " : "├── ";
        string continuation = isLast ? "    " : "│   ";

        println(prefix ~ "ForEachStmt", ident);
        
        println(continuation ~ "├── Iterator variable: " ~ iterVar, ident);
        
        if (iterVarType !is null)
            println(continuation ~ "│   └── Type: " ~ iterVarType.toStr(), ident);
        else
            println(continuation ~ "│   └── Type: (inferred)", ident);
        
        println(continuation ~ "├── Iterable:", ident);
        if (iterable !is null)
            iterable.print(ident + continuation.length + 4, false);
        else
            println(continuation ~ "│   └── (null)", ident);

        println(continuation ~ "└── Body:", ident);
        body.print(ident + continuation.length + 4, true);
    }

    override Node clone()
    {
        auto cloned = new ForEachStmt(
            this.iterVar,
            this.iterable ? this.iterable.clone() : null,
            null,
            this.loc,
            this.iterVarType ? cast(TypeExpr) this.iterVarType.clone() : null
        );
        cloned.kind = this.kind;
        cloned.type = this.type ? cast(TypeExpr) this.type.clone() : null;
        cloned.body = this.body ? cast(BlockStmt) this.body.clone() : null;
        return cloned;
    }
}

class CaseStmt : Node
{
    Node[] values; // Lista de valores (ex: 1, 2, 3). Vazio se for 'default'
    BlockStmt body;
    bool isDefault;

    this(Node[] values, BlockStmt body, Loc loc, bool isDefault = false)
    {
        this.kind = NodeKind.CaseStmt;
        this.values = values;
        this.body = body;
        this.loc = loc;
        this.isDefault = isDefault;
    }

    override void print(ulong ident = 0, bool isLast = false)
    {}

    override Node clone() {
        Node[] newValues;
        foreach(v; values) newValues ~= v.clone();
        return new CaseStmt(newValues, cast(BlockStmt)body.clone(), loc, isDefault);
    }
}

class SwitchStmt : Node
{
    Node condition;
    CaseStmt[] cases;

    this(Node condition, CaseStmt[] cases, Loc loc)
    {
        this.kind = NodeKind.SwitchStmt;
        this.condition = condition;
        this.cases = cases;
        this.loc = loc;
    }

    override void print(ulong ident = 0, bool isLast = false)
    {}

    override Node clone() {
        CaseStmt[] newCases;
        foreach(c; cases) newCases ~= cast(CaseStmt)c.clone();
        return new SwitchStmt(condition.clone(), newCases, loc);
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
