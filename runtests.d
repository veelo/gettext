import std;

int main()
{
    int result = runCommand(["dub", "test"]);
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
    foreach(lang; 0.. dirEntries(buildPath(workDir, "mo"), "*.mo", SpanMode.shallow).walkLength + 1)
    {
        auto command = ["dub", "run", "--", lang.to!string];
        writeln((workDir.length > 0 ? "cd " ~ workDir ~ " && " : ""), command.join(" "));
        auto result = execute(command, null, Config.none, size_t.max, workDir);
        writeln(result.output);
        if (result.status != 0)
            return result.status;
    }
    return 0;
}
