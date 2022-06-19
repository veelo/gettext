module gettext;

version (xgettext)
{
    import std.typecons : Tuple;
    import std.array : join;
    import std.ascii : newline;

    enum Format {plain, c}
    alias Key = Tuple!(string, "singular",
                       string, "plural",
                       Format, "format");
    private string[][Key] translatableStrings;

    string potFile;

    void main(string[] args) @safe
    {
        import std.getopt;
        import std.path : baseName, buildPath, setExtension;

        potFile = buildPath("po", args[0].baseName);

        auto helpInformation = getopt(args,
                                      "output|o", "The path for the PO template file.", &potFile);
        if (helpInformation.helpWanted)
        {
            ()@trusted{
            defaultGetoptPrinter("Usage:\n\tdub run --config=xgettext [-- <options>]\nOptions:", helpInformation.options);}();
        }
        else
            writePOT(potFile.setExtension("pot"));
    }

    private void writePOT(string potFile) @safe
    {
        import std.algorithm : map, sort;
        import std.file : mkdirRecurse, write;
        import std.path : baseName, dirName;
        import std.stdio;

        string header()
        {
            import std.exception : ifThrown;

            import std.array : join;

            import std.json;
            import std.process;

            string rootPackage = potFile.baseName;

            JSONValue json;
            auto dubResult = execute(["dub", "describe"]);
            if (dubResult.status == 0)
            {
                json = dubResult.output.parseJSON;
                rootPackage = json["rootPackage"].str.ifThrown!JSONException(potFile.baseName);
                foreach (_package; json["packages"].arrayNoRef)
                    if (_package["name"].str == rootPackage)
                    {
                        json = _package;
                        break;
                    }
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
                    .ifThrown!JSONException("# Copyright © YEAR THE PACKAGE'S COPYRIGHT HOLDER");
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
                auto _version = gitResult.status == 0 ? gitResult.output : "PACKAGE VERSION";
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
        write(potFile, header ~ translatableStrings.keys
              .sort!((a, b) => translatableStrings[a][0] < translatableStrings[b][0])
              .map!(key => messageFromKey(key)).join(newline));
        writeln(potFile ~ " generated.");
    }

    string messageFromKey(Key key) @safe
    {
        string message = `#: ` ~ translatableStrings[key].join(" ") ~ newline;
        if (key.format == Format.c)
            message ~= `#, c-format` ~ newline;
        if (key.singular.length == 0)
        {
            message ~= `msgid "` ~ key.plural ~ `"` ~ newline ~
                       `msgstr ""` ~ newline;
        }
        else
        {
            message ~= `msgid "` ~ key.singular ~ `"` ~ newline ~
                       `msgid_plural "` ~ key.plural ~ `"` ~ newline ~
                       `msgstr[0] ""` ~ newline ~
                       `msgstr[1] ""` ~ newline;
        }
        return message;
    }

    string _(string fmt,
             int line = __LINE__, string file = __FILE__, string mod = __MODULE__, string func = __FUNCTION__, Args...)(Args args)
    {
        return _!("", fmt, line, file, mod, func, Args)(args);
    }

    template _(string singular, string plural,
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
                    static if (Args.length == 0)
                        return Format.plain;
                    else
                        return Format.c;
                }
                translatableStrings[Key(singular, plural, format)] ~= reference;
            }
        }
        string _(Args args)
        {
            import std.format;

            return format(plural, args); // no-op
        }
    }
}
else
{
    /**
    Marks a translatable string.

    The string may be a format string followed by optional arguments.
    
    `_!"Hello %s"(name)` is equivalent to `std.format!"Hello %s"(name)`.

    No distinction is made for plural forms.
    */
    string _(string fmt, Args...)(Args args)
    {
        import std.format;

        return format(currentLanguage.gettext(fmt), args);
    }

    /**
    Marks a translatable string with singular and plural forms.

    Both forms may be format strings, as in
    ```
    _!("one goose", "%d geese")(n)
    ```
    */
    string _(string singular, string plural, Args...)(Args args)
    {
        import std.format;

        static assert (Args.length > 0, "Missing argument");
        static if (countFormatSpecifiers(singular) == 0)
        {
            import std.string : fromStringz;
            auto fmt = currentLanguage.ngettext(singular, plural, args[0]);
            if (countFormatSpecifiers(fmt) == 0)
                // Hack to prevent orphan format arguments if "%d" is replaced by "one" in the singular form:
                return ()@trusted{return fromStringz(&(format(fmt~"\0%s", args)[0]));}();
            return format(fmt, args);
        }
        else
        {
            return format(currentLanguage.ngettext(singular, plural, args[0]), args);
        }
    }

    private int countFormatSpecifiers(string fmt) pure @safe
    {
        import std.format : FormatSpec;

        int count = 0;
        auto f = FormatSpec!char(fmt);
        if (!__ctfe)
        {
            import std.range : nullSink;
            while (f.writeUpToNextSpec(nullSink))
                count++;
        } else {
            import std.array : appender; // std.range.nullSink does not work at CT.
            auto a = appender!string;
            while (f.writeUpToNextSpec(a))
                count++;
        }
        return count;
    }
}

import mofile;

MoFile currentLanguage;

/**
Collect a list of available *.mo files.

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
Returns the language code for the translation contained in `moFile`.
*/
string languageCode(string moFile) @safe
{
    import std.string : lineSplitter;
    import std.algorithm : filter, startsWith;
    return MoFile(moFile).gettext("").lineSplitter.filter!(a => a.startsWith("Language: ")).front["Language: ".length .. $];
}

/**
Switch to the language contained in `moFile`.
*/
void selectLanguage(string moFile) @safe
{
    import std.file : exists, isFile;

    currentLanguage = moFile.exists && moFile.isFile ? MoFile(moFile) : MoFile();
}
