/**
Internationalization compatible with $(LINK2 https://www.gnu.org/software/gettext/, GNU gettext).

Insert the following line at the top of your main function:
---
mixin(gettext.main);
---

Translatable strings are marked by instantiating the `tr` template, like so:
---
writeln(tr!"Translatable message");
---

A translation may require a particular plural form depending on a number. This can be
achieved by supplying both singular and plural forms as compile time arguments, and the
number as a runtime argument.
---
writeln(tr!("one green bottle hanging on the wall",
            "%d green bottles hanging on the wall")(n));
---

Plural forms can be used in format strings, but the argument that determines the form
must be supplied to `tr` and not to `format`. The corresponding format specifier will
not be seen by `format` as it will have been replaced with a string by `tr`:
---
format(tr!("Welcome %s, you may make a wish",
           "Welcome %s, you may make %d wishes")(n), name);
---
The format specifier that selects the form is the last specifier in the format string
(here `%d`). In many sentences, however, the specifier that should select the form cannot
be the last. In these cases, format specifiers must be given a position argument, where
the highest position determines the form:
---
foreach (i, where; [tr!"hand", tr!"bush"])
    format(tr!("One bird in the %1$s", "%2$d birds in the %1$s")(i + 1), where);
---
Again, the specifier with the highest position argument will never be seen by format.

Two identical strings that have different meanings dependent on context may need to be
translated differently. Dis can be accomplished by disambiguating the string with a
context argument. It is also possible to attach a comment that will be seen by
the translator:
---
auto message1 = tr!("Review the draft.", [Tr.context: "document"]);
auto message2 = tr!("Review the draft.", [Tr.context: "nautical",
                                          Tr.note: `Nautical term! "Draft" = how deep the bottom` ~
                                                   `of the ship is below the water level.`]);
---

If you'd rather use an underscore to mark translatable strings,
[as the GNU gettext documentation suggests](https://www.gnu.org/software/gettext/manual/html_node/Mark-Keywords.html),
you can use an alias:
---
import gettext : _ = tr;    // Customary in GNU software.
writeln(_!"Translatable message");
---

Authors:
$(LINK2 https://github.com/veelo, Bastiaan Veelo)
Copyright:
SARC B.V., 2022
License:
$(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
*/

module gettext;

/// Optional attribute categories.
enum Tr {
    note,   /// Pass a note to the translator.
    context /// Disambiguate by giving a context.
}

version (xgettext) // String extraction mode.
{
    /** $(NEVER_DOCUMENT) */
    bool scan()
    {
        import std.getopt;
        import std.path : baseName, buildPath, setExtension;
        import core.runtime : Runtime;

        auto args = Runtime.args;
        potFile = buildPath("po", args[0].baseName);

        auto helpInformation = getopt(args,
                                      "output|o", "The path for the PO template file.", &potFile);
        if (helpInformation.helpWanted)
        {
            ()@trusted{
                defaultGetoptPrinter("Usage:\n\tdub run --config=xgettext [-- <options>]\nOptions:", helpInformation.options);
            }();
        }
        else
            writePOT(potFile.setExtension("pot"));
        return args.length > 0; // Always true, but the compiler has no idea.
    }

    import std.typecons : Tuple;
    import std.array : join;
    import std.ascii : newline;

    private enum Format {plain, c}
    private alias Key = Tuple!(string, "singular",
                               string, "plural",
                               Format, "format",
                               string, "context");
    private string[][Key] translatableStrings;
    private string[][Key] comments;

    private string potFile;

    private void writePOT(string potFile) @safe
    {
        import std.algorithm : cmp, map, sort;
        import std.file : mkdirRecurse, write;
        import std.path : baseName, dirName;
        import std.stdio;

        string header() @safe
        {
            import std.exception : ifThrown;
            import std.array : join;
            import std.json, std.process;
            import std.string : strip;

            string rootPackage = potFile.baseName;

            JSONValue json;
            auto piped = pipeProcess(["dub", "describe"], Redirect.stdout);
            scope (exit) piped.pid.wait;
            json = ()@trusted{ return piped.stdout.byLine.join.parseJSON; }();
            rootPackage = json["rootPackage"].str.ifThrown!JSONException(potFile.baseName);
            foreach (_package; json["packages"].arrayNoRef)
                if (_package["name"].str == rootPackage)
                {
                    json = _package;
                    break;
                }

            string thisYear()
            {
                return __DATE__[$-4 .. $];
            }
            string title()
            {
                return "# PO Template for " ~ rootPackage ~ ".";
            }
            string copyright()
            {
                return ("# " ~ json["copyright"].str)
                    .ifThrown!JSONException("# Copyright ?? YEAR THE PACKAGE'S COPYRIGHT HOLDER");
            }
            string license()
            {
                return ("# This file is distributed under the " ~ json["license"].str ~ " license.")
                    .ifThrown!JSONException("# This file is distributed under the same license as the " ~ rootPackage ~ " package.");
            }
            string author()
            {
                return (){ return json["authors"].arrayNoRef.map!(a => "# " ~ a.str ~ ", " ~ thisYear ~ ".").join(newline); }()
                    .ifThrown!JSONException("# FIRST AUTHOR <EMAIL@ADDRESS>, " ~ thisYear ~ ".");
            }
            string idVersion()
            {
                auto gitResult = execute(["git", "describe"]);
                auto _version = gitResult.status == 0 ? gitResult.output.strip : "PACKAGE VERSION";
                return (`"Project-Id-Version: ` ~ _version ~ `\n"`);
            }
            string bugs()
            {
                return `"Report-Msgid-Bugs-To: \n"`;
            }
            string creationDate()
            {
                import std.datetime;
                return `"POT-Creation-Date: ` ~ Clock.currTime.toUTC.toISOExtString() ~ `\n"`;
            }
            return [title, copyright, license, author, `#`, `#, fuzzy`, `msgid ""`, `msgstr ""`,
                    idVersion, bugs, creationDate,
                    `"PO-Revision-Date: YEAR-MO-DA HO:MI+ZONE\n"`,
                    `"Last-Translator: FULL NAME <EMAIL@ADDRESS>\n"`,
                    `"Language-Team: LANGUAGE <LL@li.org>\n"`,
                    `"Language: \n"`,
                    `"MIME-Version: 1.0\n"`,
                    `"Content-Type: text/plain; charset=UTF-8\n"`,
                    `"Content-Transfer-Encoding: 8bit\n"`,
                    ``, ``].join(newline);
        }
        mkdirRecurse(potFile.dirName);
        ()@trusted {
            translatableStrings.rehash;
            comments.rehash;
        }();
        write(potFile, header ~ translatableStrings.keys
              .sort!((a, b) => cmp(translatableStrings[a][0], translatableStrings[b][0]) < 0)
              .map!(key => messageFromKey(key)).join(newline));
        writeln(potFile ~ " generated.");
    }

    private string stringify(string str) @safe pure
    {
        import std.conv : text;

        return text([str])[1 .. $-1];
    }

    private string messageFromKey(Key key) @safe
    {
        string message;
        if (auto c = key in comments)
            foreach (comment; *c)
                message ~= `#. ` ~ comment ~ newline;
        message ~= `#: ` ~ translatableStrings[key].join(" ") ~ newline;
        if (key.format == Format.c)
            message ~= `#, c-format` ~ newline;
        if (key.context != null)
            message ~= `msgctxt ` ~ key.context.stringify ~ newline;
        if (key.plural == null)
        {
            message ~= `msgid ` ~ key.singular.stringify ~ newline ~
                       `msgstr ""` ~ newline;
        }
        else
        {
            message ~= `msgid ` ~ key.singular.stringify ~ newline ~
                       `msgid_plural ` ~ key.plural.stringify ~ newline ~
                       `msgstr[0] ""` ~ newline ~
                       `msgstr[1] ""` ~ newline;
        }
        return message;
    }

    /** $(NEVER_DOCUMENT) */
    template tr(string singular, string[Tr] attributes = null,
                int line = __LINE__, string file = __FILE__, string mod = __MODULE__, string func = __FUNCTION__, Args...)
    {
        alias tr = tr!(singular, null, attributes,
                       line, file, mod, func, Args);
    }

    /** $(NEVER_DOCUMENT) */
    template tr(string singular, string plural, string[Tr] attributes = null,
                int line = __LINE__, string file = __FILE__, string mod = __MODULE__, string func = __FUNCTION__, Args...)
    {
        static struct StrInjector
        {
            static this()
            {
                string reference()
                {
                    import std.conv : to;
                    import std.array : join;
                    import std.algorithm : commonPrefix;
                    import std.path : buildPath, pathSplitter;

                    static if (func.length == 0)
                        return file.pathSplitter.join("/") ~ ":" ~ line.to!string;
                    else
                        return file.pathSplitter.join("/") ~ ":" ~ line.to!string ~ "(" ~ func[commonPrefix(func, mod).length + 1 .. $] ~ ")";
                }
                Format format()
                {
                    static if (Args.length > 0 || singular.hasFormatSpecifiers || (plural && plural.hasFormatSpecifiers))
                        return Format.c;
                    else
                        return Format.plain;
                }
                string context()
                {
                    if (auto c = Tr.context in attributes)
                        return *c;
                    return null;
                }
                translatableStrings.require(Key(singular, plural, format, context)) ~= reference;
                if (auto c = Tr.note in attributes)
                   comments.require(Key(singular, plural, format, context)) ~= *c;
            }
        }
        static if (plural == null)
            enum tr = TranslatableString(singular);
        else
            enum tr = TranslatableStringPlural(singular, plural);
    }

    private bool hasFormatSpecifiers(string fmt) pure @safe
    {
        import std.format : FormatSpec;

        static void ns(const(char)[] arr) {} // the simplest output range
        auto nullSink = &ns;
        return FormatSpec!char(fmt).writeUpToNextSpec(nullSink);
    }
    unittest 
    {
        assert ("On %2$s I eat %3$s and walk for %1$d hours.".hasFormatSpecifiers);
        assert ("On %%2$s I eat %%3$s and walk for %1$d hours.".hasFormatSpecifiers);
        assert (!"On %%2$s I eat %%3$s and walk for hours.".hasFormatSpecifiers);
    }
}
else // Translation mode.
{
    /**
    Translate `message`.

    This does *not* instantiate a new function for every marked string
    (the signature is fabricated for the sake of documentation).

    Returns: The translation of `message` if one exists in the selected
    language, or `message` otherwise.
    See_Also: [selectLanguage]

    Examples:
    ---
    writeln(tr!"Translatable message");
    ---
    */
    template tr(string singular, string[Tr] attributes = null)
    {
        enum tr = TranslatableString(singular, attributes);
    }
    /**
    Translate a message in the correct plural form.

    This does *not* instantiate a new function for every marked string
    (the signature is fabricated for the sake of documentation).

    The first argument should be in singular form, the second in plural
    form. Note that the format specifier `%d` is optional.

    Returns: The translation if one exists in the selected
    language, or the corresponding original otherwise.
    See_Also: [selectLanguage]

    Examples:
    ---
    writeln(tr!("There is a goose!", "There are %d geese!")(n));
    ---
    */
    template tr(string singular, string plural, string[Tr] attributes = null)
    {
        enum tr = TranslatableStringPlural(singular, plural);
    }
}
import std.format : format, FormatException, FormatSpec;

/**
Represents a translatable string.

This struct can for the most part be considered an implementation detail of `gettext`.
A template instantiation like `tr!"Greetings"` actually results in a constructor call like
`TranslatableString("Greetings")` in the code. This struct is callable, so that a lookup
of the translation happens when the struct is evaluated.

The only reason that this struct is public is to make declarations of static arrays of
translatable strings less cryptic:

---
enum RGB {red, green, blue}

// Explicit array of translatable strings:
immutable TranslatableString[Color.max + 1] colors1 = [RGB.red:   tr!"Red",
                                                       RGB.green: tr!"Green",
                                                       RGB.blue:  tr!"Blue"];
// Array of translatable strings where the type is derived:
immutable typeof(tr!"Red")[Color.max + 1] colors2 = [RGB.red:   tr!"Red",
                                                     RGB.green: tr!"Green",
                                                     RGB.blue:  tr!"Blue"];
---
*/
/*
This struct+template trick allows the string to be passed as template parameter without instantiating
a separate function for every string. https://forum.dlang.org/post/t8pqvg$20r0$1@digitalmars.com
*/
@safe struct TranslatableString
{
    private enum string soh = "\x01";
    private enum string eot = "\x04";
    private immutable(string)[] seq;
    this (string str, string[Tr] attributes = null) nothrow
    {
        if (auto context = Tr.context in attributes)
            str = soh ~ *context ~ eot ~ str;
        seq = [str];
    }
    this (string[] seq) nothrow
    {
        this.seq = seq.idup;
    }
    this (immutable(string)[] seq) nothrow
    {
        this.seq = seq;
    }
    string gettext() const
    {
        import std.algorithm : findSplitAfter, map, startsWith;
        import std.array : join;

        string proxy(string message)
        {
             if (message.startsWith(soh))
                return currentLanguage.gettext(message[1 .. $]).findSplitAfter(eot)[1];
            else
                return currentLanguage.gettext(message);
        }

        return seq.map!(a => proxy(a)).join;
    }
    alias gettext this;
    /** Forces evaluation as translated string.

    In a limited set of circumstances, a `TranslatableString` may forcefully need to be interpreted as a string.
    One of these cases is a *named* enum:

    ---
    enum E {member = tr!"translation"}
    writeln(E.member);          // "member"
    writeln(E.member.toString); // "translation"
    ---
    Contrary, anonimous enums and manifest constants do not require this treatment:
    ---
    enum {member = tr!"translation"}
    writeln(member); // "translation"
    ---
    */
    string toString() const // Called when a tr!"" literal or constant occurs in a writeln().
    {
        return gettext;
    }
    /// idem
    void toString(scope void delegate(scope const(char)[]) @safe sink) const
    {
        sink(gettext);
    }
    TranslatableString opBinary(string op : "~", RHS)(RHS rhs) nothrow
    {
        import std.traits : Unconst;

        static if (is (RHS == TranslatableString))
            return TranslatableString(seq ~ rhs.seq);
        else static if (is (Unconst!RHS == TranslatableString))
            return TranslatableString(seq ~ rhs.seq.dup);
        // TODO Add a reserved context so that ordinary strings don't accidentally get translated.
        else static if (is (RHS == string))
            return TranslatableString(seq ~ rhs);
        else static if (is (Unconst!RHS == char))
            return TranslatableString(seq ~ [rhs].idup);
        else
            static assert (false, "Need implementation for " ~ RHS.stringof);
    }
    TranslatableString opBinaryRight(string op : "~", LHS)(LHS lhs) nothrow
    {
        import std.traits : Unconst;

        static if (is (LHS == TranslatableString))
            return TranslatableString(lhs.seq ~ seq);
        static if (is (Unconst!LHS == TranslatableString))
            return TranslatableString(lhs.seq.dup ~ seq);
        // TODO Add a reserved context so that ordinary strings don't accidentally get translated.
        else static if (is (LHS == string))
            return TranslatableString([lhs] ~ seq);
        else static if (is (LHS == char[]))
            return TranslatableString([lhs.idup] ~ seq);
        else static if (is (LHS == char))
            return TranslatableString([[lhs.idup]] ~ seq);
        else
            static assert (false, "Need implementation for " ~ LHS.stringof);
    }
}
@safe struct TranslatableStringPlural
{
    string str, strpl;
    this(string str, string strpl)
    {
        this.str = str;
        this.strpl = strpl;
    }
    string opCall(size_t number) const
    {
        import std.algorithm : max;

        const n = cast (int) (number > int.max ? (number % 1000000) + 1000000 : number);
        const trans =  currentLanguage.ngettext(str, strpl, n);
        if (countFormatSpecifiers(trans) == countFormatSpecifiers(strpl))
        {
            try
                return format(trans.disableAllButLastSpecifier, n);
            catch(FormatException e)
            {
                debug throw(e);
                return strpl;   // Fall back on untranslated message.
            }
        }
        else
            return trans;
    }
}

private int countFormatSpecifiers(string fmt) pure @safe
{
    static void ns(const(char)[] arr) {} // the simplest output range
    auto nullSink = &ns;
    int count = 0;
    auto f = FormatSpec!char(fmt);
    while (f.writeUpToNextSpec(nullSink))
        count++;
    return count;
}
unittest 
{
    assert ("On %2$s I eat %3$s and walk for %1$d hours.".countFormatSpecifiers == 3);
    assert ("On %%2$s I eat %%3$s and walk for %1$d hours.".countFormatSpecifiers == 1);
}

private immutable(Char)[] disableAllButLastSpecifier(Char)(const Char[] inp) @safe
{
    import std.array : Appender;
    import std.conv : to;
    import std.exception : enforce;
    import std.typecons : tuple;

    enum Mode {undefined, inSequence, outOfSequence}
    Mode mode = Mode.undefined;

    Appender!(Char[]) outp;
    outp.reserve(inp.length + 10);
    // Traverse specs, disable all of them, note where the highest index is. Re-enable that one.
    size_t lastSpecIndex = 0, highestSpecIndex = 0, highestSpecPos = 0, specs = 0;
    auto f = FormatSpec!Char(inp);
    while (f.trailing.length > 0)
    {
        if (f.writeUpToNextSpec(outp))
        {
            // Mode check.
            if (mode == Mode.undefined)
                mode = f.indexStart > 0 ? Mode.outOfSequence : Mode.inSequence;
            else
                enforce!FormatException( mode == Mode.inSequence && f.indexStart == 0 ||
                                        (mode == Mode.outOfSequence && f.indexStart != lastSpecIndex),
                        `Cannot mix specifiers with and without a position argument in "` ~ inp ~ `"`);
            // Track the highest.
            if (f.indexStart == 0)
                highestSpecPos = outp[].length + 1;
            else
                if (f.indexStart > highestSpecIndex)
                {
                    highestSpecIndex = f.indexStart;
                    highestSpecPos = outp[].length + 1;
                }
            // disable
            auto curFmtSpec = inp[outp[].length - specs .. $ - f.trailing.length];
            outp ~= '%'.to!Char ~ curFmtSpec;
            lastSpecIndex = f.indexStart;
            specs++;
        }

    }
    return mode == Mode.inSequence ?
        (outp[][0 .. highestSpecPos] ~ outp[][highestSpecPos + 1 .. $]).idup :
        (outp[][0 .. highestSpecPos] ~ outp[][highestSpecPos + highestSpecIndex.to!string.length + 2 .. $]).idup;
}
unittest
{
    import std.exception;

    assert ("?? ???????????? %d ????????????.".disableAllButLastSpecifier ==
            "?? ???????????? %d ????????????.");
    assert ("Last %s, in %s, I ate %d muffins".disableAllButLastSpecifier ==
            "Last %%s, in %%s, I ate %d muffins");
    assert ("I ate %3$d muffins on %1$s in %2$s.".disableAllButLastSpecifier ==
            "I ate %d muffins on %%1$s in %%2$s.");
    assertThrown("An unpositioned %d specifier mixed with positioned specifier %3$s".disableAllButLastSpecifier);
    assertThrown("A positioned specifier %3$s mixed with unpositioned %d specifier".disableAllButLastSpecifier);
}

/**
Code to be mixed in at the top of your `main()` function.

Examples:
---
void main()
{
    import gettext;
    mixin(gettext.main);

    // Your code.
}
---
*/
enum main = q{
    version (xgettext)
    {
        if (scan) // Prevent unreachable code warning after mixin.
        {
            import std.traits : ReturnType;
            static if (is (ReturnType!main == void))
                return;
            else
                return 0;
        }
    }
};

import mofile;

private MoFile currentLanguage;

/**
Collect a list of available `*.mo` files.

If no `moPath` is given, files are searched inside the `mo` folder assumed
to exist besides the file location of the running executable.
*/
string[] availableLanguages(string moPath = null)
{
    import std.algorithm: map;
    import std.array : array;
    import std.file : exists, isDir, dirEntries, SpanMode;
    import std.path : buildPath, dirName;

    if (moPath == null)
    {
        import core.runtime : Runtime;
        moPath = buildPath(Runtime.args[0].dirName, "mo");
    }

    if (moPath.exists && moPath.isDir)
        return dirEntries(moPath, "*.mo", SpanMode.shallow).map!(a => a.name).array;

    return null;
}

/**
Returns the language code for the current language.
*/
string languageCode() @safe
{
    import std.string : lineSplitter;
    import std.algorithm : find, startsWith;
    auto l = currentLanguage.header.lineSplitter.find!(a => a.startsWith("Language: "));
    return l.empty ? "Default" : l.front["Language: ".length .. $];
}

/**
Returns the language code for the translation contained in `moFile`.
*/
string languageCode(string moFile) @safe
{
    import std.string : lineSplitter;
    import std.algorithm : find, startsWith;
    auto l = MoFile(moFile).header.lineSplitter.find!(a => a.startsWith("Language: "));
    return l.empty ? "Undefined" : l.front["Language: ".length .. $];
}

/**
Switch to the language contained in `moFile`.
*/
void selectLanguage(string moFile) @safe
{
    import std.file : exists, isFile;

    currentLanguage = moFile.exists && moFile.isFile ? MoFile(moFile) : MoFile();
}
