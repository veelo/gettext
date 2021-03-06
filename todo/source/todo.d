import std.stdio;

int main()
{
    import std.process : execute;
    import std.json;
    import std.array;

    auto command = ["dub", "describe"];
    auto dubResult = execute(command);
    if (dubResult.status != 0)
    {
        writeln("Failed to execute \"", command.join(" "), "\":\n", dubResult.output);
        return dubResult.status;
    }
    auto json = dubResult.output.parseJSON;
    foreach (_package; json["packages"].arrayNoRef)
        if (_package["name"].str == json["rootPackage"].str)
        {
            json = _package;
            break;
        }

    foreach (file; json["files"].arrayNoRef)
        if (file["role"].str == "source")
            todo(file["path"].str);

    return 0;
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
