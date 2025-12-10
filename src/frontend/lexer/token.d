module frontend.lexer.token;

import std.variant, std.stdio, std.conv;

enum TokenKind
{
    Struct,
    Import,
    Sizeof,
    Return,
    Type,
    If,
    Else,
    For,
    While,
    Break,
    Continue,
    Version,

    True,
    False,
    Null,

    Identifier, // ID
    I32,
    I64,
    F32,
    F64,
    String, // "FernandoDev"
    Char,
    Bool,
    Void,

    LParen, // (
    RParen, // )
    LBrace, // {
    RBrace, // }
    LBracket, // [
    RBracket, // ]
    Plus, // +
    PlusPlus, // ++
    Minus, // -
    MinusMinus, // --
    Star, // *
    Slash, // /
    Comma, // ,
    Colon, // :
    SemiColon, // ;
    Equals, // =
    Dot, // .
    Bang, // !
    Question, // ?
    Modulo, // %

    GreaterThan, // >
    GreaterThanEquals, // >=
    LessThan, // <
    LessThanEquals, // <=
    Or, // ||
    And, // &&
    EqualsEquals, // ==
    NotEquals, // ==
    Arrow, // ->

    BitAnd, // &
    BitOr, // |
    BitXor, // ^
    BitNot, // ~
    BitSHL, // <<
    BitSHR, // >>
    BitSAR, // >>>

    BitAndEquals, // &=
    BitOrEquals, // |=
    BitXorEquals, // ^=
    BitSHLEquals, // <<=
    BitSHREquals, // >>=

    PlusEquals, // +=
    MinusEquals, // -=
    StarEquals, // *=
    SlashEquals, // /=
    ModuloEquals, // %=
    TildeEquals, // ~=
    Variadic, // ...

    Eof // EndOfFile
}

struct Token
{
    TokenKind kind;
    Variant value;
    Loc loc;

    void print()
    {
        writeln("Type: ", kind);
        writeln("Value: ", to!string(value));
        writeln("Position: ", loc, "\n");
    }
}

struct LocLine
{
    ulong offset;
    ulong line;
}

struct Loc
{
    string filename;
    string dir;
    LocLine start;
    LocLine end;
}
