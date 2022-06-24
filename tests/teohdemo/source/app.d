import std.conv : to;
import mod1, mod2;

void main(string[] args)
{
    import gettext;
    mixin(gettext.main);

    selectLanguage(args);
    foreach (i, name; ["Joe", "Schmoe", "Jane", "Doe"])
    {
        fun1(name);
        fun2(1 + i.to!int * 2);
    }
}

void selectLanguage(string[] args)
{
    import gettext, std.stdio;

    int choice = -1;
    string[] languages = availableLanguages;
    if (args.length > 1)
        choice = args[1].to!int;
    else
    {
        writeln("Please select a language:");
        writeln("[0] default");
        foreach (i, language; languages)
            writeln("[", i + 1, "] ", language.languageCode);
        readf(" %d", &choice);
    }
    if (choice < 1 || choice > languages.length)
        gettext.selectLanguage(null);
    else
        gettext.selectLanguage(languages[choice - 1]);
}
