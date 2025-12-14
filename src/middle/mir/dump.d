module middle.mir.dump;

import middle.mir.mir;
import std.stdio;
import std.conv : to;

void dumpMir(MirProgram prog) {
    writeln("\n=== MIR Dump ===");
    foreach(func; prog.functions) {
        writefln("func @%s {", func.name);
        
        foreach(block; func.blocks) {
            writefln("  %s:", block.name);
            
            foreach(instr; block.instructions) {
                dumpInstr(instr);
            }
        }
        writeln("}\n");
    }
}

private void dumpInstr(MirInstr instr) {
    write("    "); // Indentação da instrução

    // Se a instrução gera resultado (tem destino), imprime "%n = "
    if (instr.dest.type !is null && instr.op != MirOp.Store && instr.op != MirOp.Br && instr.op != MirOp.CondBr && 
        instr.op != MirOp.Ret) {
        writef("%s = ", formatVal(instr.dest));
    }

    // Imprime o Opcode
    write(formatOp(instr.op));

    // Imprime operandos
    foreach(i, op; instr.operands) {
        if (i == 0) write(" ");
        else write(", ");
        write(formatVal(op));
    }
    writeln();
}

private string formatVal(MirValue val) {
    if (val.isConst) {
        // Se for constante, mostra o valor
        if (val.type !is null)
            if (val.type.isNumeric()) return to!string(val.constInt);
        // if (val.type.isFloat) return to!string(val.constFloat);
        return "const";
    } else {
        // Se for registrador, mostra %0, %1...
        return "%" ~ to!string(val.regIndex);
    }
}

private string formatOp(MirOp op) {
    switch(op) {
        case MirOp.Alloca: return "alloca";
        case MirOp.Store:  return "store";
        case MirOp.Load:   return "load";
        case MirOp.Add:    return "add";
        case MirOp.Sub:    return "sub";
        case MirOp.Mul:    return "mul";
        case MirOp.ICmp:   return "icmp";
        case MirOp.Br:     return "br";
        case MirOp.CondBr: return "cond_br";
        case MirOp.Call:   return "call";
        case MirOp.Ret:    return "ret";
        case MirOp.BitCast: return "bitcast";
        case MirOp.GetElementPtr: return "getelementptr";
        default: return to!string(op);
    }
}
