import std.array;
import std.file;
import std.getopt;
import std.path;
import std.process;
import std.stdio;
import std.range;
import std.typecons;
import std.string;
import std.algorithm;
import colorize;

int main(string[] args) {
    string poPath, gettextPath;

    enum Return {success = 0, error}

    auto helpInformation = getopt(
                                  args,
                                  std.getopt.config.passThrough,
                                  "p|popath",      "Path to Portable Object input files.", &poPath,
                                  "g|gettextpath", "Path to the msgmerge utility, part of GNU gettext.", &gettextPath);

    if (helpInformation.helpWanted)
    {
        defaultGetoptPrinter("Merging a new PO template into existing PO translations.\nOptions:",
                             helpInformation.options);
        return Return.success;
    }

    auto msgmerge = buildPath(gettextPath, "msgmerge");
    try execute(msgmerge);
    catch(ProcessException)
    {
        writeln("Error: Could not find the \"msgmerge\" utility.\n",
                "       Please supply its path with the \"--gettextpath\" option.");
        return Return.error;
    }

    auto poFiles = dirEntries(poPath, "*.po", SpanMode.shallow);
    if (poFiles.empty)
    {
        writeln("Warning: No \".po\" files found at \"", poPath, "\", nothing to merge\n",
                "         Make sure to supply their path with the \"--popath\" option.");
        return Return.success;
    }

    auto potFiles = dirEntries(poPath, "*.pot", SpanMode.shallow);
    if (potFiles.empty)
    {
        writeln("Warning: No \".pot\" file found at \"", poPath, "\", nothing to merge\n",
                "         Make sure to supply its path with the \"--popath\" option.");
        return Return.success;
    }
    if (potFiles.walkLength > 1)
    {
        writeln("Error: Multiple \".pot\" files found at \"", poPath, "\", cannot choose.");
        return Return.error;
    }
    auto potFile = potFiles.front;

    foreach (poFile; poFiles)
    {
        auto commands = [msgmerge, poFile, potFile, "--update"] ~ args[1 .. $];
        writeln(commands.join(" "));
        auto result = execute(commands);
        if (result.status != 0)
        {
            writeln(result.output);
            return result.status;
        }
        bool inHeader = true;
        foreach (line; File(poFile).byLine)
        {
            if (inHeader)
            {
                if (line.strip.length == 0)
                    inHeader = false;
                continue;
            }
            if (line.startsWith("#, fuzzy") ||
                (line.startsWith("msgstr") && line.endsWith(`""`)))
            {
                cwriteln("WARNING: ".color("yellow"), poFile, " needs work.");
                break;
            }
        }
    }

    return Return.success;
}
