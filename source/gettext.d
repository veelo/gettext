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
        write(potFile, header ~ translatableStrings.keys.map!(key => messageFromKey(key)).join(newline));
        writeln(potFile ~ " generated.");
    }

    string messageFromKey(Key key) @safe
    {
        string message = `#: ` ~ translatableStrings[key].join(" ") ~ newline;
        if (key.format == Format.c)
            message ~= `", c-format` ~ newline;
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

    template _(string fmt, int line = __LINE__, string file = __FILE__, string mod = __MODULE__, string func = __FUNCTION__, Args...)
    {
        string _(Args args)
        {
            return _!("", fmt, line, file, mod, func, Args)(args);
        }
    }

    template _(string singular, string plural, int line = __LINE__, string file = __FILE__, string mod = __MODULE__, string func = __FUNCTION__, Args...)
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

        return format(fmt, args); // TODO
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

        return format(plural, args); // TODO
    }
}
