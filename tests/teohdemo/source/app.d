import std.conv : to;
import mod1, mod2;

version (xgettext) {} else
void main()
{
    selectLanguage;
    foreach (i, name; ["Joe", "Schmoe", "Jane", "Doe"])
    {
        fun1(name);
        fun2(1 + i.to!int * 2);
    }
}

void selectLanguage()
{
    import gettext, std.stdio;

    string[] languages = availableLanguages;
    writeln("Please select a language:");
    writeln("[0] default");
    foreach (i, language; languages)
        writeln("[", i + 1, "] ", language.languageCode);
    int choice = -1;
    readf(" %d", &choice);
    if (choice < 1 || choice > languages.length)
        gettext.selectLanguage(null);
    else
        gettext.selectLanguage(languages[choice - 1]);
}
