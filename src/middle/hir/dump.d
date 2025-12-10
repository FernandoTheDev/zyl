module middle.hir.dump;

import middle.hir.hir;
import std.stdio;

void dumpHir(HirProgram prog) {
    writeln("\n=== HIR Dump ===");
    auto dumper = new HirDumper();
    dumper.dump(prog);
}

private class HirDumper {
    void dump(HirProgram prog) {
        writeln("HirProgram");
        foreach(i, func; prog.globals)
            printNode(func, "", i == cast(int)prog.globals.length - 1);
    }

    void printNode(HirNode node, string indent, bool isLast) {
        if (node is null) return;

        string marker = isLast ? "└── " : "├── ";
        string nextIndent = indent ~ (isLast ? "    " : "│   ");

        write(indent, marker, node.kind);

        // Detalhes extras baseados no tipo do nó
        switch(node.kind) {
            case HirNodeKind.Function:
                auto f = cast(HirFunction)node;
                writeln(" (", f.name, ") -> ", f.returnType.toStr());
                if (f.body !is null)
                    printChildren(f.body.stmts, nextIndent);
                break;

            case HirNodeKind.Block:
                auto b = cast(HirBlock)node;
                writeln();
                printChildren(b.stmts, nextIndent);
                break;

            case HirNodeKind.VarDecl:
                auto v = cast(HirVarDecl)node;
                writeln(": ", v.name, " (", v.type.toStr(), ")");
                if (v.initValue) printNode(v.initValue, nextIndent, true);
                break;

            case HirNodeKind.IntLit:
                auto i = cast(HirIntLit)node;
                writeln(": ", i.value, " (", i.type.toStr(), ")");
                break;
            
            case HirNodeKind.FloatLit:
                auto f = cast(HirFloatLit)node;
                writeln(": ", f.value, " (", f.type.toStr(), ")");
                break;

            case HirNodeKind.StringLit:
                auto s = cast(HirStringLit)node;
                writeln(": \"", s.value, "\"");
                break;

            case HirNodeKind.Binary:
                auto b = cast(HirBinary)node;
                writeln(" (", b.op, ") : ", b.type.toStr());
                printNode(b.left, nextIndent, false);
                printNode(b.right, nextIndent, true);
                break;

            case HirNodeKind.Store:
                auto s = cast(HirStore)node;
                writeln();
                printNode(s.ptr, nextIndent, false);  // Onde guarda
                printNode(s.value, nextIndent, true); // O que guarda
                break;

            case HirNodeKind.If:
                auto i = cast(HirIf)node;
                writeln();
                // Condition
                writeln(nextIndent, "├── Cond:"); 
                printNode(i.condition, nextIndent ~ "│   ", true);
                // Then
                writeln(nextIndent, "├── Then:");
                printNode(i.thenBlock, nextIndent ~ "│   ", i.elseBlock is null);
                // Else
                if (i.elseBlock) {
                    writeln(nextIndent, "└── Else:");
                    printNode(i.elseBlock, nextIndent ~ "    ", true);
                }
                break;
            
            case HirNodeKind.AddrOf:
                auto a = cast(HirAddrOf)node;
                writeln(" (Target: ", a.varName, ") : ", a.type.toStr());
                break;

            case HirNodeKind.Load:
                auto l = cast(HirLoad)node;
                writeln(" (Src: ", l.varName, ") : ", l.type.toStr());
                break;

            // Default fallback para nós simples
            default:
                if (node.type !is null) write(" : ", node.type.toStr());
                writeln();
                break;
        }
    }

    void printChildren(HirNode[] nodes, string indent) {
        foreach(i, node; nodes) {
            printNode(node, indent, i == nodes.length - 1);
        }
    }
}
