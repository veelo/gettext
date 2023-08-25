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

enum Color {red, green, blue}

// Static array
immutable TranslatableString[3] colors1 = [tr!"Red",
                                           tr!"Green",
                                           tr!"Blue"];
immutable typeof(tr!"Red")[Color.max + 1] colors2 = [Color.red:   tr!"Red",
                                                     Color.green: tr!"Green",
                                                     Color.blue:  tr!"Blue"];

// Dynamic array
immutable clrs = [tr!"Red",
                  tr!"Green",
                  tr!"Blue"];

struct Event
{
    auto day = monday;
    auto city = tr!"Gothenburg"; // Marked static initializer.
    int muffins = 1;
}

private const one = tr!"One ";

void main(string[] args)
{
    mixin(gettext.main);
    import std.stdio;
    import std.format;
    import std.conv;
    
    selectLanguage(args);

    // All current and future string formats are recognised.
    static const json = tr!(`"dependencies": { "gettext": "*" }`);
    static const path = tr!(r"C:\Program Files\gettext-iconv\bin\msgfmt.exe");
    static const delimited = tr!(q"EOS
This
is a multi-line
heredoc string
EOS");

    // Concatenation
    static const tr_and_tr = tr!"One " ~ tr!"sentence.";
    assert (tr_and_tr.toString ==     tr!"One sentence.".toString);
    static const tr_and_string = tr!"One " ~ "sentence.";
    assert (tr_and_string.toString == tr!"One sentence.".toString);
    static const tr_and_char = tr!"One sentence" ~ '.';
    assert (tr_and_char.toString ==   tr!"One sentence.".toString);
    static const string_and_tr = "One " ~ tr!"sentence.";
    assert (string_and_tr.toString == tr!"One sentence.".toString);
    static const tr_sequence = tr!"One" ~ " " ~ tr!"sentence" ~ '.';
    assert (tr_sequence.toString ==   tr!"One sentence.".toString);
    static const sentence = "sentence";
    static const even = "even";
    static const mix = tr!"One " ~ sentence ~ ".";
    static const longer = tr!"One " ~ even ~ tr!" longer " ~ sentence ~ ".";
    static const global_const = one ~ tr!"sentence.";

    immutable onez = tr!"One" ~ '\0';

    // Pass a note to the translator.
    auto name = tr!("Walter Bright", [Tr.note: "Proper name. Phonetically: ˈwɔltər braɪt"]);

    // Disambiguate identical sentenses.
    auto labelOpenFile    = tr!("Open", [Tr.context: "Menu|File|Open"]);
    auto labelOpenPrinter = tr!("Open", [Tr.context: "Menu|File|Printer|Open"]);

    auto message1 = tr!("Review the draft.", [Tr.context: "document"]);
    auto message2 = tr!("Review the draft.", [Tr.context: "nautical",
                                              Tr.note: `Nautical term! "Draft" = how deep the bottom ` ~
                                                       `of the ship is below the water level.`]);
    writeln(message1);
    writeln(message2);

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

    foreach (i; [1, 5])
    {
        writeln(tr!("One license.", "%d licenses.", [Tr.context: "software", Tr.note: "Notice to translator."])(i));
        writeln(tr!("One license.", "%d licenses.", [Tr.context: "driver's"])(i));
    }

    mixin(`writeln(tr!"This is mixed in code.");`);
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
