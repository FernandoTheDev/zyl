module frontend.semantic.semantic1;

import frontend;
import std.file : exists, readText;
import std.path : buildPath, absolutePath, dirName, extension;
import std.algorithm : canFind;
import common.reporter, env;

struct ModuleCacheEntry {
    Context ctx;
    Program program;
}

class Semantic1
{
    Context ctx;
    DiagnosticError error;
    Node[] importedASTs;
    static ModuleCacheEntry[string] modulesCache;
    TypeRegistry registry;

    this(Context ctx, TypeRegistry registry, DiagnosticError error)
    {
        this.ctx = ctx;
        this.error = error;
        this.registry = registry;
    }

    pragma(inline, true)
    void reportError(string message, Loc loc, Suggestion[] suggestions = null)
    {
        error.addError(Diagnostic(message, loc, suggestions));
    }

    pragma(inline, true)
    void reportWarning(string message, Loc loc, Suggestion[] suggestions = null)
    {
        error.addWarning(Diagnostic(message, loc, suggestions));
    }

    void analyze(Program program)
    {
        foreach (node; program.body)
            collectDeclaration(node);

        if (importedASTs.length > 0)
        {
            program.body = importedASTs ~ program.body;
            importedASTs = []; 
        }
    }

    void collectDeclaration(Node node)
    {
        if (auto varDecl = cast(VarDecl) node)
            collectVarDecl(varDecl);
        else if (auto funcDecl = cast(FuncDecl) node)
            collectFunctionDecl(funcDecl);
        else if (auto _version = cast(VersionStmt) node)
            collectVersionStmt(_version);
        else if (auto decl = cast(StructDecl) node)
            collectStructDecl(decl);
        else if (auto mod = cast(ImportStmt) node)
            collectImportStmt(mod);
        else if (auto enm = cast(EnumDecl) node)
            collectEnumDecl(enm);
        else if (auto un = cast(UnionDecl) node)
            collectUnionDecl(un);
    }

    void collectImportStmt(ImportStmt node)
    {
        string filename = node.modulePath;
        if (filename.extension != ".zl") filename ~= ".zl";
        
        string resolvedPath = buildPath(node.loc.dir, filename);
        
        if (!exists(resolvedPath))
        {
            loadEnv();
            string stdPath = buildPath(MAIN_DIR, filename);
            
            if (exists(stdPath))
                resolvedPath = stdPath;
            else
            {
                reportError("File not found (neither local nor stdlib): " ~ filename, node.loc);
                return;
            }
        }

        string fullPath = absolutePath(resolvedPath);

        Context importedCtx;
        Program importedProgram;

        if (fullPath in modulesCache)
        {
            importedCtx = modulesCache[fullPath].ctx;
            importedProgram = modulesCache[fullPath].program;

            // reportWarning("The module has been imported more than once; this time it will be imported from the cache.", 
            //     node.loc);
        }
        else
        {
            importedCtx = new Context(error);
            try 
            {
                string src = readText(fullPath);
                Lexer lexer = new Lexer(fullPath, src, dirName(fullPath), this.error);
                Token[] tokens = lexer.tokenize();
                Parser parser = new Parser(tokens, this.error, registry); // Assumindo construtor compatível
                importedProgram = parser.parseProgram();

                new Semantic1(importedCtx, registry, this.error).analyze(importedProgram);
                new Semantic2(importedCtx, error, registry).analyze(importedProgram);

                modulesCache[fullPath] = ModuleCacheEntry(importedCtx, importedProgram);
            }
            catch (Exception e)
            {
                reportError("Fatal error during import: " ~ e.msg, node.loc);
                return;
            }
        }

        bool isSelective = node.symbols.length > 0;
        foreach (importedNode; importedProgram.body)
        {
            if (importedNode.kind == NodeKind.ImportStmt) continue;

            string nodeName = getNodeName(importedNode);
            if (nodeName == "") continue;

            // Verifica se o símbolo é público no contexto original
            Symbol originalSym = importedCtx.lookupLocal(nodeName);
            if (originalSym is null || !originalSym.isPublic) continue;
            bool shouldImport = false;

            if (isSelective)
            {
                if (node.symbols.canFind(nodeName))
                    shouldImport = true;
            }
            else
                shouldImport = true;

            if (shouldImport)
            {
                if (!ctx.importSymbol(originalSym, node.aliasname))
                {
                    // se falhou e foi seletivo, apenas ignore o erro
                    if (isSelective)
                    {
                        reportError(format("The symbol '%s' already exists in the context..", originalSym.name), 
                            node.loc);
                        continue;
                    }
                    continue;
                }
                importedASTs ~= importedNode;
            }
        }
        
        if (isSelective)
        {
            foreach (reqSym; node.symbols)
            {
                Symbol sym = importedCtx.lookupLocal(reqSym);
                if (sym is null){}
                    // reportError("The symbol '" ~ reqSym ~ "' does not exist in " ~ filename, node.loc);
                else if (!sym.isPublic)
                    reportError("The symbol '" ~ reqSym ~ "' is private.", node.loc);
            }
        }
    }

    string getNodeName(Node node)
    {
        if (auto fd = cast(FuncDecl) node) return fd.name;
        if (auto sd = cast(StructDecl) node) return sd.name;
        if (auto vd = cast(VarDecl) node) return vd.id;
        return "";
    }

    void collectStructDecl(StructDecl decl)
    {
        if (ctx.isDefined(decl.name))
        {
            reportError(format("Struct redefinition '%s'", decl.name), decl.loc);
            return;
        }
        StructType realType = new StructType(decl.name, decl.fields, decl.methods);
        StructSymbol symbol = new StructSymbol(decl.name, realType, decl, decl.loc);
        ctx.addStruct(symbol);
    }

    void collectEnumDecl(EnumDecl decl)
    {
        if (ctx.isDefined(decl.name))
        {
            reportError(format("Enum redefinition '%s'", decl.name), decl.loc);
            return;
        }
        EnumType realType = new EnumType(decl.name, decl.members);
        EnumSymbol symbol = new EnumSymbol(decl.name, realType, decl, decl.loc);
        ctx.addEnum(symbol);
    }

    void collectUnionDecl(UnionDecl decl)
    {
        if (ctx.isDefined(decl.name))
        {
            reportError(format("Union redefinition '%s'", decl.name), decl.loc);
            return;
        }
        UnionType realType = new UnionType(decl.name, decl.fields);
        UnionSymbol symbol = new UnionSymbol(decl.name, realType, decl, decl.loc);
        ctx.addUnion(symbol);
    }

    void collectVersionStmt(VersionStmt stmt)
    {
        bool[string] validTargets = [
            "linux": true,
            "windows": true,
            "darwin": true,
        ];

        if (stmt.target !in validTargets) {
            reportError(format("Invalid version target '%s'. Valid targets are: linux, windows, darwin", 
                        stmt.target), stmt.loc);
            return;
        }

        bool shouldExecuteThen = false;
        
        version(linux) {
            if (stmt.target == "linux")
                shouldExecuteThen = true;
        }
        else version(Windows) {
            if (stmt.target == "windows")
                shouldExecuteThen = true;
        }
        else version(Darwin) {
            if (stmt.target == "darwin")
                shouldExecuteThen = true;
        }

        if (shouldExecuteThen) {
            if (stmt.thenBranch !is null) {
                foreach (node; stmt.thenBranch.statements)
                    collectDeclaration(node);
                stmt.resolvedBranch = stmt.thenBranch;
            }
        }
        else {
            if (stmt.elseBranch !is null)
                collectVersionStmt(stmt.elseBranch); // Recursivo
        }
    }

    void collectVarDecl(VarDecl decl)
    {
        if (ctx.isDefined(decl.id))
        {
            reportError(format("Redefining '%s'", decl.id), decl.loc);
            return;
        }

        Type tempType = null;
        if (!ctx.addVariable(decl.id, tempType, decl.isConst, decl.loc))
            reportError(format("Error adding variable '%s'", decl.id), decl.loc);
    }

    void collectFunctionDecl(FuncDecl decl)
    {
        // if (ctx.isDefined(decl.name))
        // {
        //     reportError(format("Function redefinition '%s'", decl.name), decl.loc);
        //     return;
        // }

        // // Tipos dos parâmetros serão resolvidos no semantic2
        // // Por enquanto, cria símbolo vazio
        // Type[] paramTypes;
        // foreach (param; decl.args)
        //     paramTypes ~= null; // será preenchido depois

        // Type returnType = null; // será preenchido depois

        // auto funcSym = new FunctionSymbol(
        //     decl.name,
        //     paramTypes,
        //     returnType,
        //     decl,
        //     decl.loc
        // );

        // funcSym.isExternal = decl.body is null;

        // if (!ctx.addFunction(funcSym))
        //     reportError(format("Error adding function '%s'", decl.name), decl.loc);
    }
}
