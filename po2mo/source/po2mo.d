import std.array;
import std.file;
import std.getopt;
import std.path;
import std.process;
import std.stdio;

int main(string[] args) {
    string poPath, moPath, gettextPath;

    enum Return {success = 0, error}

    auto helpInformation = getopt(
                                  args,
                                  std.getopt.config.passThrough,
                                  "p|popath",      "Path to Portable Object input files.", &poPath,
                                  "m|mopath",      "Path to Machine Object output files.", &moPath,
                                  "g|gettextpath", "Path to the msgfmt utility, part of GNU gettext.", &gettextPath);

    if (helpInformation.helpWanted)
    {
        defaultGetoptPrinter("Batch conversion from .po files into .mo files.\nOptions:",
                             helpInformation.options);
        return Return.success;
    }

    auto msgfmt = buildPath(gettextPath, "msgfmt");
    try execute(msgfmt);
    catch(ProcessException)
    {
        writeln("Error: Could not find the \"msgfmt\" utility.\n",
                "       Please supply its path with the \"--gettextpath\" option.");
        return Return.error;
    }

    auto poFiles = dirEntries(poPath, "*.po", SpanMode.shallow);
    if (poFiles.empty)
    {
        writeln("Error: No \".po\" files found at \"", poPath, "\".\n",
                "       Please supply their path with the \"--popath\" option.");
        return Return.error;
    }

    if (!moPath.exists)
        mkdirRecurse(moPath);

    Pid[] pids;
    foreach (poFile; poFiles)
    {
        auto commands = [msgfmt, poFile, "--no-hash", "-o", buildPath(moPath.pathSplitter.buildPath, poFile.baseName.setExtension(".mo"))] ~ args[1 .. $];
        writeln(commands.join(" "));
        pids ~= spawnProcess(commands);
    }
    foreach (pid; pids)
        pid.wait;

    return Return.success;
}
