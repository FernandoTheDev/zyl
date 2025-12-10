module backend.builder;

import middle.mir.mir, middle.hir.hir;
import backend.llvm.codegen;
import target; // Import do TargetInfo
import cli : CompilerConfig; // Importa a struct de configuração
import std.process : executeShell, escapeShellCommand;
import std.stdio : writeln, writefln, stderr;
import std.file : exists, remove;
import std.format : format;

enum BackendType 
{
    LLVM
}

class BackendBuilder 
{
    static void build(MirProgram mir, HirProgram hir, TargetInfo target, CompilerConfig config) 
    {    
        // Por enquanto só temos LLVM, mas a arquitetura permite expansão
        buildLLVM(mir, hir, target, config);
    }

    private static void buildLLVM(MirProgram mir, HirProgram hir, TargetInfo target, CompilerConfig config) 
    {
        // 1. Gera o IR do LLVM
        if (config.verbose) writefln("[Backend] Generating LLVM IR...");
        
        auto codegen = new LLVMBackend();
        codegen.initializeTargetData(target);
        codegen.generate(mir, hir);
        
        // Define o nome do arquivo intermediário
        // Se a saída for "myapp", o IR será "myapp.ll"
        string irFilename = config.outputFile ~ ".ll";
        codegen.dumpToFile(irFilename);

        if (config.verbose) writefln("[Backend] IR written to: %s", irFilename);

        // 2. Compila para Nativo usando Clang
        if (config.verbose) writefln("[Backend] Compiling to native (Opt: -O%d)...", config.optLevel);
        
        // Constrói o comando do Clang dinamicamente
        string[] cmdArgs = [
            "clang",
            irFilename,
            "-o", config.outputFile,
            format("-O%d", config.optLevel), // Nível de otimização
            "-lm",                           // Linka com Math Library (libc)
            "-Wno-override-module"           // Silencia warning comum de IR gerado manualmente
        ];

        // Se quiser debug info no futuro:
        // if (config.optLevel == 0) cmdArgs ~= "-g";

        // Cria a string do comando para execução segura
        string cmd = escapeShellCommand(cmdArgs);

        if (config.verbose) writefln("[Exec] %s", cmd);
        
        auto result = executeShell(cmd);
        
        // 3. Verifica Resultado
        if (result.status != 0) 
        {
            stderr.writeln("\n\033[1;31m[CLANG ERROR]\033[0m Compilation failed:");
            stderr.writeln(result.output);
            
            // Em caso de erro, mantemos o .ll para debug do usuário
            stderr.writefln("Intermediate file preserved at: %s", irFilename);
            import core.stdc.stdlib : exit;
            exit(result.status);
        }
        
        // 4. Limpeza (Cleanup)
        // Se o usuário NÃO pediu para emitir LLVM (--emit-llvm), deletamos o arquivo .ll
        if (!config.emitLLVM && exists(irFilename))
        {
            if (config.verbose) writefln("[Backend] Cleaning up %s...", irFilename);
            remove(irFilename);
        }
    }
}
