module env;
import std.stdio, std.file, std.path, std.process, core.stdc.stdlib : exit;

const string VERSION = "0.1.0";
string HOME, MAIN_DIR, DIR_BIN;

void loadEnv()
{
    version (linux)
    {
        HOME = environment.get("HOME");
        MAIN_DIR = HOME ~ "/.zyl/";
        if (!exists(MAIN_DIR))
            mkdir(MAIN_DIR);
    }
    else version (Windows)
    {
        // suporte parcial
        // caracteres especiais podem ser imprimidos de forma incorreta
        // preciso testar muitos casos ainda, além do sistema de arquivos que necessitará
        // além disso, será preciso criar um instalador pro Windows
        // ele irá baixar alguma release pelo github, extrair o binario apenas e setar o PATH corretamente
        // não sei muito sobre instaladores do windows então se eu puder embutir o binario no instalador então assim farei
        import core.sys.windows.windows;

        writeln("NOTICE: Windows has partial support.");
        SetConsoleOutputCP(65_001);
        SetConsoleCP(65_001);
        // vou dar a saida precoce pois sei que o suporte é inexistente
        exit(69);
    }
    else
    {
        writeln("Your operating system is not supported.");
        exit(1);
    }

    // valida se alguma das variaveis importantes não foram definidas
    // deixei essa validação para suprir todos os casos de erros que podem vir a ocorrer
    if (!exists(MAIN_DIR)|| !exists(HOME))
    {
        writeln(
            "There was an error defining some global variables; please create an issue in the repository.");
        exit(1);
    }
}
