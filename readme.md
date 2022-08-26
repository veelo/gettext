# Gettext

The [GNU `gettext` utilities](https://www.gnu.org/software/gettext/) provide a well established solution for the internationalization of software. It allows users to switch between natural languages without switching executables. Many commercial translation offices can work with GNU `gettext` message catalogs (Portable Object files, PO), and various editors exist that help with the translation process. The translation process and programming process can happen asynchronously and without knowledge of eachother. New translations can be added without recompilation.

The use of GNU `gettext` in D has been enabled by the [mofile](https://code.dlang.org/packages/mofile) package, that this Gettext package builds on. If you would only use `mofile` directly then you would depend on the GNU `xgettext` utility for the task of string extraction, hoping it can parse D code as if it were C code. You would also be dealing with a number of limitations that are native to GNU `gettext`.

This Gettext package removes the need for an external parser and provides a more powerful interface than GNU `gettext` itself. It combines convenient and reliable string extraction - enabled by D's unique language features - and a comprehensive integration with Dub, while leveraging a well established ecosystem for translation into other natural languages.

### Contents
- [Features](#features)
- [Installation](#installation)
    - [Dub configuration](#dub-configuration)
    - [`main()` function](#main-function)
    - [Ignore generated files](#ignore-generated-files)
- [Usage](#usage)
    - [Marking strings](#marking-strings)
    - [Plural forms](#plural-forms)
    - [Marking format strings](#marking-format-strings)
    - [Concatenations](#concatenations)
    - [Passing attributes](#passing-attributes)
        - [Passing notes to the translator](#passing-notes-to-the-translator)
        - [Disambiguate identical sentences](#disambiguate-identical-sentences)
    - [Selecting a translation](#selecting-a-translation)
    - [Finding unmarked strings](#finding-unmarked-strings)
    - [Fixing compilation errors](#fixing-compilation-errors)
    - [Added steps to the build process](#added-steps-to-the-build-process)
        - [Creating/updating the PO template automatically](#creatingupdating-the-PO-template-automatically)
        - [Updating existing translations automatically](#updating-existing-translations-automatically)
        - [Converting to binary form automatically](#converting-to-binary-form-automatically)
    - [Adding translations](#adding-translations)
    - [Updating translations](#updating-translations)
- [Example](#example-1)
- [Impact on footprint and performance](#impact-on-footprint-and-performance)
- [Limitations](#limitations)
    - [Wide strings](#wide-strings)
    - [Forced string evaluation](#forced-string-evaluation)
    - [Named enums](#named-enums)
- [Credits](#credits)
- [Todo](#todo)

# Features

- Concise translation markers that can be aliased to your preference.
- All marked strings that are seen by the compiler are extracted automatically.
- All (current and future) [D string literal formats](https://dlang.org/spec/lex.html#string_literals) are supported.
- Static initializers of fields, constants, immutables, manifest constants and anonimous enums can be marked as translatable (a D specialty).
- Concatenations of translatable strings, untranslated strings and single chars are supported, even in initializers.
- Arrays of translatable strings are supported, also when statically initialized.
- Plural forms are language dependent, and play nice with format strings.
- Multiple identical strings are translated once, unless they are given different contexts.
- Notes to the translator can be attached to individual translatable strings.
- Code occurrences of strings are communicated to the translator.
- Available languages are discovered and selected at run-time.
- Platfom independent, not linked with C libraries.
- Automated generation of the PO template.
- Automated merging into existing translations (requires [GNU `gettext` utilities](https://www.gnu.org/software/gettext/)).
- Automated generation of Machine Object files (MO) (requires [GNU `gettext` utilities](https://www.gnu.org/software/gettext/)).
- Includes utility for listing unmarked strings in the project.

# Installation

## Dub configuration

Add the following to your `dub.json` (or its SDLang equivalent to your `dub.sdl`):

```json
    "dependencies": {
        "gettext": "~>1.0"
    },
    "configurations": [
        {
            "name": "default",
            "preBuildCommands": [
                "dub run --config=xgettext",
                "dub run gettext:merge -- --popath=po --backup=none",
                "dub run gettext:po2mo -- --popath=po --mopath=mo"
            ],
            "copyFiles": [
                "mo"
            ]
        },
        {
            "name": "xgettext",
            "targetPath": ".xgettext",
            "versions": [ "xgettext" ],
            "subConfigurations": {
                "gettext": "xgettext"
            }
        }
    ]
```
This may seem quite the boiler plate, but it automates many steps without taking away your control over them. We'll discuss these further below.

## `main()` function

Insert the following line at the top of your `main` function:
```d
mixin(gettext.main);
```

## Ignore generated files

The PO template and MO files are generated, and need not be kept under version control. The executable in the `.xgettext` folder is an artefact of the string extraction process. If you use Git, add these lines to `.gitignore`:
```
.xgettext
*.pot
*.mo
```

# Usage

## Marking strings

Prepend `tr!` in front of every string literal that needs to be translated. For instance:
```d
writeln(tr!"This string is to be translated");
writeln("This string will remain untranslated.");
```

## Plural forms

Sentences that should change in plural form depending on a number should supply both singlular and plural forms with the number like this:
```d
// Before:
writefln("%d green bottle(s) hanging on the wall", n);
// After:
writeln(tr!("one green bottle hanging on the wall",
            "%d green bottles hanging on the wall")(n));
```
Note that the format specifier (`%d`, or `%s`, etc.) is optional in the singular form.

Many languages have not just two forms like the English language does, and translations in those languages can supply all the forms that the particular language requires. This is handled by the translator, and is demonstrated in [the example below](#example-1).

If `tr` is too verbose for you, you can change it to whatever you want:
```d
import gettext : _ = tr;
writeln(_!"No green bottles...");
```

## Marking format strings

Translatable strings can be format strings, used with `std.format` and `std.stdio.writefln` etc. These format strings do support plural forms, but the argument that determines the form must be supplied to `tr` and not to `format`. The corresponding format specifier will not be seen by `format` as it will have been replaced with a string by `tr`. Example:
```d
format(tr!("Welcome %s, you may make a wish",
           "Welcome %s, you may make %d wishes")(n), name);
```
The format specifier that selects the form is the last specifier in the format string (here `%d`). In many sentences, however, the specifier that should select the form cannot be the last. In these cases, format specifiers must be given a position argument, where the highest position determines the form:
```d
foreach (i, where; [tr!"hand", tr!"bush"])
    format(tr!("One bird in the %1$s", "%2$d birds in the %1$s")(i + 1), where);
```
Again, the specifier with the highest position argument will never be seen by `format`. On a side note, some translations may need a reordering of words, so translators may need to use position arguments in their translated format strings anyway.

Note: Specifiers with and without a position argument must not be mixed.

## Concatenations

Translators will be able to produce the best translations if they get to work with full sentences, like
```d
auto message = format(tr!`Could not open the file "%s" for reading.`, file);
```
However, in support of legacy code, concatenations of strings do work:
```d
auto message = tr!`Could not open the file "` ~ file ~ tr!`" for reading.`;
```

## Passing attributes

Optionally, two kinds of attributes can be passed to `tr`, in the form of an associative array initializer. These are for passing notes to the translator and for disambiguating identical sentences with different meanings.

### Passing notes to the translator

Sometimes a sentence can be interpreted to mean different things, and then it is important to be able to clarify things for the translator. Here is an example of how to do this:
```d
auto name = tr!("Walter Bright", [Tr.note: "Proper name. Phonetically: ˈwɔltər braɪt"]);
```

The GNU `gettext` manual has a section [about the translation of proper names](https://www.gnu.org/software/gettext/manual/html_node/Names.html).

### Disambiguate identical sentences

Multiple occurrences of the same sentence are combined into one translation by default. In some cases, that may not work well. Some language, for example, may need to translate identical menu items in different menus differently. These can be disambiguated by adding a context like so:
```d
auto labelOpenFile    = tr!("Open", [Tr.context: "Menu|File"]);
auto labelOpenPrinter = tr!("Open", [Tr.context: "Menu|File|Printer"]);
```

Notes and comments can be combined in any order:
```d
auto message1 = tr!("Review the draft.", [Tr.context: "document"]);
auto message2 = tr!("Review the draft.", [Tr.context: "nautical",
                                          Tr.note: `Nautical term! "Draft" = how deep the bottom` ~
                                                   `of the ship is below the water level.`]);
```

## Selecting a translation

Use the following functions to discover translation tables, get the language code for a table and activate a translation:
```d
string[] availableLanguages(string moPath = null)
string languageCode() @safe
string languageCode(string moFile) @safe
void selectLanguage(string moFile) @safe
```
Note that any translation that happens before a language is selected, results in the value of the hard coded string.

## Finding unmarked strings

To get an overview of all string literals in your project that are not marked as translatable, execute the following in your project root folder:
```shell
dub run gettext:todo -q
```
This prints a list of strings with their source file names and row numbers.

## Fixing compilation errors

An attempt to translate a static string initializer will cause a compilation error, because the language is only selected at run-time. For example:
```d
const string statically_initialized = tr!"Compile-time translation?";
```
will produce an error like this:
```
d:\SARC\gettext\source\gettext.d(285,20): Error: static variable `currentLanguage` cannot be read at compile time
source\mod1.d(7,24):        called from here: `TranslatableString("Compile-time translation?").gettext()`
```

Unless you're initializing a mutable static variable, the solution is to remove the explicit `string` type and let the type be inferred:
```d
const statically_initialized = tr!"Compile-time translation!";
```

The correct translation will then be retrieved at the places where this constant is used, at run-time.

The way this works is that the type of the constant gets to be inferred as `TranslatableString`, which is a callable struct defined by this package. Whenever an instance of this struct is evaluated, the value of the translation is retrieved.

But, there are places where you wouldn't want to change the type away from `string`, like the initializer of a mutable static variable or an aggregate member. In these cases there is no other way than to move to run-time assignment until after the language has been selected.

## Added steps to the build process

With the `preBuildCommands` and `copyFiles` that you've added to your default Dub configuration, a couple of tasks are automated:
1. Translatable strings are extracted from the sources into a PO template.
1. Translations in any existing PO files are updated according to the new template.
1. PO files are converted into binary MO files.
1. MO files are copied to the target directory.

We'll discuss these in a little more detail below.

### Creating/updating the PO template automatically

In other languages, string extraction into a `.pot` file is done by invoking the `xgettext` tool from the GNU `gettext` utilities. Because `xgettext` does not know about all the string literal syntaxes in D, we employ D itself to perform this task.

This is how this works: The `dub run --config=xgettext` line in the  `preBuildCommands` section of your Dub configuration compiles and runs your project into an alternative `targetPath` and executes the code that you have mixed in at the top of your `main()` function. That code makes smart use of D language features ([see credits](#credits)) to collect all strings that are to be translated, together with information from your Dub configuration and the latest Git tag. The rest of your `main()` is ignored in this configuration. In any other configuration the mixin is actually empty.

By default this creates (or overwrites) the PO template in the `po` folder of your project. This can be changed by using options; To see which options are accepted, run the command with the `--help` option:
```shell
dub run --config=xgettext -- --help
```

#### Example
The `teohdemo` test contained in this package produces the following `teohdemo.pot`:
```po
# PO Template for teohdemo.
# Copyright © 2022, SARC B.V.
# This file is distributed under the BSL-01 license.
# Bastiaan Veelo, 2022.
#
#, fuzzy
msgid ""
msgstr ""
"Project-Id-Version: v1.0.4\n"
"Report-Msgid-Bugs-To: \n"
"POT-Creation-Date: 2022-07-09T20:52:52.4027136Z\n"
"PO-Revision-Date: YEAR-MO-DA HO:MI+ZONE\n"
"Last-Translator: FULL NAME <EMAIL@ADDRESS>\n"
"Language-Team: LANGUAGE <LL@li.org>\n"
"Language: \n"
"MIME-Version: 1.0\n"
"Content-Type: text/plain; charset=UTF-8\n"
"Content-Transfer-Encoding: 8bit\n"

#: source/app.d:10(main)
#, c-format
msgid "Selected language: %s"
msgstr ""

#: source/mod1.d:13(fun1) source/mod2.d:15(fun3)
msgid "Identical strings share their translation!"
msgstr ""

#: source/mod1.d:7
#, c-format
msgid "Hello! My name is %s."
msgstr ""

#: source/mod2.d:13(fun3)
msgid "Never used, but nevertheless translated!"
msgstr ""

#: source/mod2.d:8(fun2)
#, c-format
msgid "I'm counting one apple."
msgid_plural "I'm counting %d apples."
msgstr[0] ""
msgstr[1] ""
```

### Updating existing translations automatically

The `"dub run gettext:merge -- --popath=po"` pre-build command invokes the `merge` script that is included as a subpackage. This script runs the `msgmerge` utility from GNU `gettext` on the PO files that it finds. When needed, the path to `msgmerge` can be specified with the `--gettextpath` option. Any additional options are passed on to `msgmerge` directly, [see its documentation](https://www.gnu.org/software/gettext/manual/html_node/msgmerge-Invocation.html). For example, you can use the `--backup=numbered` option to keep backups of original translations.

Note that if translatable strings were changed in the source, or new ones were added, the PO file is now incomplete. This is detected by the script, which then prints a warning. Changed strings are marked as `#, fuzzy` in the PO file, which can be picked up by editors as needing work. If a lookup in an outdated MO file does not succeed, the application will show the string as it occurs in the source.

### Converting to binary form automatically

Similar to the previous step, the `"dub run gettext:po2mo -- --popath=po --mopath=mo"` pre-build command invokes the `po2mo` subpackage, which runs the `msgfmt` utility from GNU `gettext`. This converts all PO files into MO files in the `mo` folder. This folder is then copied to the target directory for inclusion in the distribution of your package. Any additional options are passed on to `msgfmt` directly, [see its documentation](https://www.gnu.org/software/gettext/manual/html_node/msgfmt-Invocation.html).

## Adding translations

Each natural language that is going to be supported requires a `.po` file, which is derived from the generated `.pot` template file. This `.po` file is then edited to fill in the stubs with the correct translations.

There are various tools to do this, from dedicated stand-alone editors, editor plugins or modes, web applications to command line utilities.

Currently my presonal favourite is [Poedit](https://poedit.net/). You open the template, select the target language and start translating with real-time suggestions from various online translation engines. Or you let the AI give it its best effort and translate all messages at once, before reviewing the problematic ones (requires subscription). It supports marking translations that need work and adding notes.

## Updating translations

Any translations that have fallen behind the template will need to be updated by a translator. To detect any such translations, you can scan for warnings in the output of this command:
```shell
dub run -q gettext:merge -- --popath=po
```
and look for warnings. Warnings will also show if GNU `gettext` detected what it thinks is a mistake. Sadly it sometimes gets it wrong: Weekdays, for example, are capitalized in English but not in many other languages. If a translation string only consists of one word, a weekday, it guesses that it is the start of a sentence and will complain if the translation does not start with a capital letter. Therefore, translatable strings should be full sentences if at all possible.

PO file editors will typically allow translators to quickly jump between strings that need their attention.

After a PO file has been edited, MO files must be regenerated with this command:
```shell
dub run gettext:po2mo -- --popath=po --mopath=mo
```

Currently, Dub does not detect changes in PO files only; Either issue the command by hand or `--force` a recompilation of your project.

# Example

These are some runs of the included `teohdemo` test:
```
d:\SARC\gettext\tests\teohdemo>dub run -q
Please select a language:
[0] default
[1] en_GB
[2] nl_NL
[3] uk_UA
1
Hello! My name is Joe.
I'm counting one apple.
Hello! My name is Schmoe.
I'm counting 3 apples.
Hello! My name is Jane.
I'm counting 5 apples.
Hello! My name is Doe.
I'm counting 7 apples.

d:\SARC\gettext\tests\teohdemo>dub run -q
Please select a language:
[0] default
[1] en_GB
[2] nl_NL
[3] uk_UA
3
Привіт! Мене звати Joe.
Я рахую 1 яблуко.
Привіт! Мене звати Schmoe.
Я рахую 3 яблука.
Привіт! Мене звати Jane.
Я рахую 5 яблук.
Привіт! Мене звати Doe.
Я рахую 7 яблук.
```
Notice how the translation of "apple" in the last translation changes with three different endings dependent on the number of apples.

# Impact on footprint and performance

The implementation of Gettext keeps generated code to a minium. Although the `tr` template is instantiated many times with unique parameters, it does not instatiate a new function each time. All that is left of a `tr` instantiation after compilation are the references to the strings that were passed in.

The discovery of translatable strings happens at compile time in the `xgettext` configuration, and the generation of the PO template happens during execution of the result of that compilation. So this at least doubles compile times of your projects. If that is problematic, the `preBuildCommands` and `copyfiles` in `dub.json` can be moved out of the `default` configuration into a `translate` or `release` configuration, so that this cost is not paid during ordinary development.

There is a run time cost to the lookup of strings in the MO file. Currently, [mofile](https://code.dlang.org/packages/mofile) reads the entire file into memory and does a binary search for the untranslated string to find the translated string. In case the cost of this lookup would become noticable, `mofile` could easily be modified to cache the search with `std.functional.memoize`. Even memoizing a small number of lookups could have a big inpact on the evaluations in an event loop. 

# Limitations

## Wide strings

Attempts to translate a `wstring` or `dstring` will result in a compilation error:
```d
auto w = tr!"Hello"w; // Error: template `gettext.tr` does not match any template declaration
```

It would be pointless for this package to try and support all string widths. After all, the `hello` literal above is assembled as an array of UTF-8 chars, which is then [converted to wstring](https://dlang.org/spec/lex.html#string_postfix). GNU `gettext` works internally with UTF-8, so it would need to convert the wstring from UTF-16 back to UTF-8, and after translation convert to UTF-16 again before it returns.

This limitation is easily dealt with by converting the translated string after lookup:
```d
auto w = tr!"Hello".to!wstring;
```

## Forced string evaluation

In some cases it may be necessary to forcefully evaluate a translatable string as a string instead of a `TranslatableString` instance:
```d
static const tr_and_tr = tr!"One " ~ tr!"sentence.";
assert (tr_and_tr.toString == tr!"One sentence.".toString); // Fails without `.toString`.
```

## Named enums

Members of *named* enums need forced string evaluation, otherwise they resolve to the member identifier name instead:
```d
enum E {member = tr!"translation"}
writeln(E.member);          // "member"
writeln(E.member.toString); // "translation"
```
Contrary, anonimous enums and manifest constants do not require this treatment:
```d
enum {member = tr!"translation"}
writeln(member); // "translation"
```

# Credits

This package was sponsored by SARC B.V. 
The idea for automatic string extraction came from H.S. Teoh [[1]](https://forum.dlang.org/post/mailman.2526.1585832475.31109.digitalmars-d@puremagic.com), [[2]](https://forum.dlang.org/post/mailman.4770.1596218284.31109.digitalmars-d-announce@puremagic.com), with optimizations by Steven Schveighoffer [[3]](https://forum.dlang.org/post/t8pqvg$20r0$1@digitalmars.com). Reading of MO files was implemented by Roman Chistokhodov [[4]](https://code.dlang.org/packages/mofile).

# TODO

Investigate the merit of:
- [Domains](https://www.gnu.org/software/gettext/manual/html_node/Triggering.html) and [Library support](https://www.gnu.org/software/gettext/manual/html_node/Libraries.html).
- Default language selection dependent on system Locale.
- Using [Compendia](https://www.gnu.org/software/gettext/manual/html_node/Compendium.html).
