module app;

import std.stdio, std.file, std.getopt, std.path, std.format;
import frontend, common.reporter, env, cli, middle, target;
import middle.hir.hir, middle.hir.lowering, middle.hir.dump;
import middle.mir.mir, middle.mir.lowering, middle.mir.dump;
import backend.llvm.codegen, backend.builder;
import core.stdc.stdlib : exit;
import cli;

CompilerConfig config;

void fatal(Args...)(string fmt, Args args)
{
    stderr.writefln("\033[1;31m[FATAL]\033[0m " ~ fmt, args);
    exit(1);
}

void logInfo(Args...)(string fmt, Args args)
{
    if (config.verbose) writefln("\033[1;34m[INFO]\033[0m " ~ fmt, args);
}

void logSuccess(string msg)
{
    if (config.verbose) writefln("\033[1;32m[SUCCESS]\033[0m %s", msg);
}

void checkErrors(DiagnosticError erro)
{
    if (erro.hasErrors() || erro.hasWarnings())
    {
        erro.printDiagnostics();
        if (erro.hasErrors()) exit(1);
        erro.clear();
    }
}

void printVersion()
{
    enum ORANGE_PLUS = "\033[38;5;208m+\033[0m";
    enum GRAY_PLUS   = "\033[90m+\033[0m";

    string rawLogo = `
      ++++++++++++          ++++         
      +++++++++++           ++++         
           ++++             ++++         
   ...   +++++    ++++  ++++++++ ...     
..      +++++     +++++++++ ++++     ..  
  ...  +++++        ++++++  ++++ ...     
      ++++++++++++   ++++   ++++         
      +++++++++++   ++++     ++          
                   ++++                  
                  ++++                                  
`;

    string renderedLogo = rawLogo
        .replace("+", ORANGE_PLUS)
        .replace(".", GRAY_PLUS);

    writeln(renderedLogo);
    writeln("Zyl Compiler v", VERSION);
    writeln("Built with LDC2 - (c) 2025 Zyl Lang Team");
}

void printHelp()
{
    writeln("Usage: zyl [options] <file.zl>");
    writeln("\nOptions:");
    writeln("  --of, --output <file>  Specify output binary filename (default: a.out)");
    writeln("  -O, --opt-level <n>    Set optimization level (0=Debug, 3=Release)");
    writeln("  --emit-llvm            Generate human-readable .ll file");
    writeln("  --dump-hir             Print HIR representation to stdout");
    writeln("  --dump-mir             Print MIR representation to stdout");
    writeln("  --target <triple>      Compile for a specific target (e.g., x86_64-linux-gnu)");
    writeln("  -v, --verbose          Enable verbose logging");
    writeln("  --version              Show compiler version");
    writeln("  --help                 Show this help message");
    writeln("\nExamples:");
    writeln("  zyl main.zl");
    writeln("  zyl -O 3 -o myapp main.zl");
    writeln("  zyl --emit-llvm --verbose main.zl");
}

string extractDir(string path)
{
	string dir = dirName(path);
	return dir == "." || dir == "" ? "." : dir;
}

void main(string[] args)
{
    DiagnosticError error = new DiagnosticError();
    bool helpWanted = false;
    bool versionWanted = false;

    try
    {
        getopt(
            args,
            std.getopt.config.passThrough,
            "of|output",     &config.outputFile,
            "O|opt-level",  &config.optLevel,
            "emit-llvm",    &config.emitLLVM,
            "dump-mir",     &config.dumpMir,
            "dump-hir",     &config.dumpHir,
            "target",       &config.targetTriple,
            "v|verbose",    &config.verbose,
            "version",      &versionWanted,
            "help",         &helpWanted,
            "C|clang",      &config.compilerArg,
        );

        if (helpWanted)
        {
            printHelp();
            return;
        }

        if (versionWanted)
        {
            printVersion();
            return;
        }

        if (args.length < 2)
            fatal("No input file provided. Run 'zyl --help' for usage.");

        config.inputFile = args[1];

        if (!exists(config.inputFile))
            fatal("File '%s' not found.", config.inputFile);

        logInfo("Compiling '%s'...", config.inputFile);

        // --- Pipeline Start ---

        string src = readText(config.inputFile);
        string pathRoot = extractDir(config.inputFile);
        Token[] tokens = new Lexer(config.inputFile, src, pathRoot, error).tokenize();
        TypeRegistry registry = new TypeRegistry();

        Program program = new Parser(tokens, error, registry, pathRoot).parseProgram();
        checkErrors(error);

        Context ctx = new Context(error);
        TypeChecker checker = new TypeChecker(ctx, error, registry);

        new Semantic1(ctx, registry, error, pathRoot, checker).analyze(program);
        checkErrors(error);

        new Semantic2(ctx, error, registry, null, checker).analyze(program);
        checkErrors(error);

        new Semantic3(ctx, error, registry, pathRoot, checker).analyze(program);
        checkErrors(error);

        // program.print();

        HirProgram hir = new AstLowerer().lower(program);
        
        if (config.dumpHir)
        {
            writeln("\n=== HIR DUMP ===");
            dumpHir(hir); 
            writeln("================\n");
        }

        MirProgram mir = new HirToMir().lower(hir);

        if (config.dumpMir)
        {
            writeln("\n=== MIR DUMP ===");
            dumpMir(mir);
            writeln("================\n");
        }

        logInfo("Generating code (Opt: O%d)...", config.optLevel);

        TargetInfo triple = config.targetTriple == ""? getTarget() : TargetInfo(config.targetTriple);

        BackendBuilder.build(
            mir, 
            hir, 
            triple, 
            config
        );

        logSuccess("Build complete: " ~ config.outputFile);
    }
    catch (Exception e)
    {
        // Se o erro já foi reportado pelo DiagnosticError, o exit(1) já ocorreu lá.
        // Se chegou aqui, é um crash interno do compilador (NullPointer, etc).
        if (!error.hasErrors())
        {
            stderr.writeln("\n\033[1;31m[INTERNAL COMPILER ERROR]\033[0m");
            stderr.writeln(e.msg); // Mensagem curta
            if (config.verbose) stderr.writeln(e.info); // Stack trace só no verbose
            exit(1);
        }
        error.printDiagnostics();
        if (config.verbose) writeln(e);
    }
}
