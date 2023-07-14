import std.stdio;

int main()
{
    import std.array : appender, join;
    import std.json;
    import std.process : pipeProcess, Redirect, wait;
    import std.range : empty;

    auto command = ["dub", "describe"];
    auto dubDescribe = pipeProcess(command, Redirect.stdout);
    auto a = appender!string;
    foreach (ubyte[] chunk; dubDescribe.stdout.byChunk(4096))
        a.put(chunk);
    if (dubDescribe.pid.wait != 0)
    {
        std.stdio.stderr.writeln("Failed to execute \"", command.join(" "), "\".\n");
        return dubDescribe.pid.wait;
    }
    auto json = a.data.parseJSON;
    
    foreach (_package; json["packages"].arrayNoRef)
        if (_package["name"].str == json["rootPackage"].str)
        {
            json = _package;
            break;
        }

    if (json["files"].arrayNoRef.empty)
    {
        std.stdio.stderr.writeln(`Root package `, json["name"], ` does not contain files. Maybe it has "targetType": "none"?`);
        std.stdio.stderr.writeln;
        return 1;
    }
    foreach (file; json["files"].arrayNoRef)
        if (file["role"].str == "source" && file["path"].str.isDSource)
            todo(file["path"].str);

    return 0;
}

bool isDSource(string file)
{
    import std.algorithm : endsWith;

    return (file.endsWith(".d") || file.endsWith(".di") || file.endsWith(".dpp"));
}

void todo(string file)
{
    import std.file : readText;
    import dparse.lexer : getTokensForParser, LexerConfig, StringCache;
    import dparse.parser : parseModule;
    import dparse.rollback_allocator : RollbackAllocator;

    auto cache = StringCache(StringCache.defaultBucketCount);
    RollbackAllocator rba;

    scope visitor = new TodoVisitor;
    visitor.file = file;
    visitor.visit(readText(file).getTokensForParser(LexerConfig(), &cache).parseModule(file, &rba));
}

import dparse.ast : ASTVisitor;

class TodoVisitor : ASTVisitor
{
    import dparse.lexer : Token, tok;
    import dparse.ast : ImportDeclaration, TemplateInstance;

    alias visit = ASTVisitor.visit;

    string file, marker;
    bool isTranslatable = false;

    override void visit(const ImportDeclaration decl)
    {
        scope (exit) decl.accept(this);
        foreach (singleImport; decl.singleImports)
        {
            if (singleImport.identifierChain &&
                singleImport.identifierChain.identifiers.length &&
                singleImport.identifierChain.identifiers[0].text == "gettext")
            {
                marker = "tr";
                return;
            }
        }

        if (decl.importBindings && decl.importBindings.singleImport && decl.importBindings.singleImport.identifierChain &&
            decl.importBindings.singleImport.identifierChain.identifiers.length &&
            decl.importBindings.singleImport.identifierChain.identifiers[0].text == "gettext")
        {
            foreach (bind; decl.importBindings.importBinds)
                if (bind.right.text == "tr")
                {
                    marker = bind.left.text;
                    return;
                }
        }
    }

    override void visit(const TemplateInstance inst)
    {
        if (inst.identifier.text == marker)
        {
            isTranslatable = true;
            inst.accept(this);
            isTranslatable = false;
        }
        else
            inst.accept(this);
    }

    override void visit(const Token token)
    {
        if (token.type == tok!"stringLiteral" && !isTranslatable)
            writeln(file, ":", token.line, ": ", token.text);
    }
}
