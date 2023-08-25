import std;

int main()
{
    int result = runCommand(["dub", "test"]);
    if (result != 0)
        return result;

    result = runCommand(["dub", "test", "--config=xgettext"]);
    if (result != 0)
        return result;

    foreach (test; dirEntries("tests", SpanMode.shallow))
    {
        if (!test.isDir)
            continue;
        result = runTest(test.name);
        if (result != 0)
            return result;
    }
    return 0;
}

int runCommand(string[] command, string workDir = null)
{
    writeln((workDir.length > 0 ? "cd " ~ workDir ~ " && " : ""), command.join(" "));
    auto result = execute(command, null, Config.none, size_t.max, workDir);
    writeln(result.output);
    return result.status;
}

int runTest(string workDir)
{
    auto result = runCommand(["dub", "build", "--config=i18n"], workDir);
    if (result != 0)
        return result;

    // Check for translatable strings in .pot file.
    foreach (potFile; dirEntries(buildPath(workDir, "po"), "*pot", SpanMode.shallow))
        assert (potFile.readText.lineSplitter.count!(a => a.startsWith("msgid")) > 1,
                "No translatable strings were extracted.");

    foreach(lang; 0.. dirEntries(buildPath(workDir, "mo"), "*.mo", SpanMode.shallow).walkLength + 1)
    {
        result = runCommand(["dub", "run", "--", lang.to!string], workDir);
        if (result != 0)
            return result;
    }
    return 0;
}
