module cli;

struct CompilerConfig
{
    string inputFile;
    string outputFile = "a.out";
    int optLevel = 0; 
    bool emitLLVM = false;
    bool dumpMir = false;
    bool dumpHir = false;
    bool verbose = false;
    string targetTriple = "";
    string compilerArg = "";
}
