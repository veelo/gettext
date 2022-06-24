import gettext;

// Compile-time marking of translatable strings.
enum {
    monday    = tr!"Monday",
    tuesday   = tr!"Tuesday",
    wednesday = tr!"Wednesday",
    thursday  = tr!"Thursday",
    friday    = tr!"Friday",
    saturday  = tr!"Saturday",
    sunday    = tr!"Sunday",
}

struct Event
{
    auto day = monday;
    auto city = tr!"Gothenburg"; // Marked in static initializer.
    int muffins = 1;
}

void main(string[] args)
{
    mixin(gettext.main);
    import std.stdio;
    import std.format;
    import std.conv;
    
    selectLanguage(args);

    // All current and future string formats are recognised.
    auto json = tr!(`"dependencies": { "gettext": "*" }`);
    auto path = tr!(r"C:\Program Files\gettext-iconv\bin\msgfmt.exe");
    auto delimited = tr!(q"EOS
This
is a multi-line
heredoc string
EOS");

    // Pass a note to the translator.
    auto name = tr!("Walter Bright", [Tr.note: "Proper name. Phonetically: ˈwɔltər braɪt"]);

    // Disambiguate identical sentenses.
    auto labelOpenFile    = tr!("Open", [Tr.context: "Menu|File|Open"]);
    auto labelOpenPrinter = tr!("Open", [Tr.context: "Menu|File|Printer|Open"]);

    auto message1 = tr!("Review the draft.", [Tr.context: "document"]);
    auto message2 = tr!("Review the draft.", [Tr.context: "nautical",
                                              Tr.note: `Nautical term! "Draft" = how deep the bottom` ~
                                                       `of the ship is below the water level.`]);

    // Translation of format strings.
    auto f = format(tr!"Format the %s", "string");

    // Plural form in format strings.
    void report(Event event)
    {
        // Plural form selector is the last format specifier, here %d.
        writeln(format(tr!("Last %s, in %s, I ate a muffin.",
                           "Last %s, in %s, I ate %d muffins.")(event.muffins), event.day, event.city));
        // If the plural form selector cannot be last, then use position arguments.
        // The format specifier with the highest position is the plural form selector, here %3.
        writeln(format(tr!("I ate a muffin in %1$s on %2$s.",
                           "I ate %3$d muffins in %1$s on %2$s.")(event.muffins), event.city, event.day));
        // Mixing positioned and unpositioned format specifiers is not allowed for plural form translations.
        // Debug builds will throw a FormatException, release builds will fall back to untranslated strings.
        version (none) auto illegal = tr!("%3$s %s", "%3$s %s")(3);
    }

    report(Event(wednesday));
    report(Event(saturday, tr!"Copenhagen", 3));
    Event event;
    event.city = tr!"Sidney";
    report(event);

    void fun(string message) {}
    fun(tr!"message");

    void funW(wstring message) {}
    version (none) funW(tr!"wmessage"w); // No go.
    funW(tr!"message".to!wstring);

}

void selectLanguage(string[] args)
{
    import std.stdio, std.conv;

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
