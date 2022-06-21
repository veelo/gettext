# Gettext

This Dub package provides internationalization functionality that is compatible with the [GNU `gettext` utilities](https://www.gnu.org/software/gettext/). It combines convenient and reliable string extraction - enabled by D's unique language features - with existing well established utilities for translation into other natural languages. The resulting translation tables are loaded at run-time, allowing users to switch between natural languages within the same software distribution. Many commercial translation offices support GNU `gettext` message catalogs (the PO files, for Portable Object), and various editors exist that help with the translation process. The translation process is separated from the programming process, so that they may happen asynchronously and without knowledge of eachother. New translations may be added without recompilation.

## Features

- All marked strings that are seen by the compiler are extracted automatically.
- Constants, immutables, static initializers and even enums can be marked as translatable (a D specialty).
- Multiple identical strings are translated once.
- References to the source location of the original strings are maintained.
- Available languages are discovered and selected at run-time.
- Plural forms are supported and language dependent.
- Platfom independent, no dependencies on C libraries.
- Automated generation of the PO template.
- Automated merging into existing translations (requires [GNU `gettext` utilities](https://www.gnu.org/software/gettext/)).
- Automated generation of MO files (Machine Object) (requires [GNU `gettext` utilities](https://www.gnu.org/software/gettext/)).
- Includes utility for listing unmarked strings in the project.

## Installation

### Dub configuration

Add the following to your `dub.json` (or its SDLang equivalent to your `dub.sdl`):

```json
    "dependencies": {
        "gettext": "*"
    },
    "configurations": [
        {
            "name": "default",
            "postBuildCommands": [
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

### `main()` function

Insert the following line at the top of your `main` function:
```d
mixin(gettext.main);
```

### Ignore generated files

The PO template and machine object files are generated, and need not be kept under version control. The executable in the `.xgettext` folder is an artefact in the string extraction process. If you use Git, add these lines to `.gitignore`:
```
.xgettext
*.pot
*.mo
```

## Usage

### Marking strings

Prepend `tr!` in front of every string literal that needs to be translated. For instance:
```d
writeln(tr!"This string is to be translated");
writeln("This string will remain untranslated.");
```

Sentences that should change in plural form depending on a number should supply both singlular and plural forms with the number like this:
```d
// Before:
writefln("%d green bottle(s) hanging on the wall", n);
// After:
writeln(tr!("one green bottle hanging on the wall",
            "%d green bottles hanging on the wall")(n));
```
Note that the format specifier (`%d`, or `%s`, etc.) is optional in the singular form.

Many languages have not just two forms like the english language does, and translations in those languages can supply all the forms that the particular language requires.

### Selecting a translation

Use the following functions to discover translation tables, get the language code for a table and activate a translation:
```d
string[] availableLanguages(string moPath = null)
string languageCode(string moFile) @safe
void selectLanguage(string moFile) @safe
```
Note that any translation that happens before a language is selected, results in the value of the hard coded string.

### Finding unmarked strings

To get an overview of all string literals in your project that are not marked as translatable, execute the following in your project root folder:
```shell
dub run gettext:todo -q
```
This prints a list of strings with their source file names and row numbers.

### Fixing compilation errors

An attempt to translate a static string initializer will cause a compilation error, because the language is only selected at run-time. For example:
```d
const string statically_initialized = tr!"Compile-time translation?";
```
will produce an error like this:
```
d:\SARC\gettext\source\gettext.d(285,20): Error: static variable `currentLanguage` cannot be read at compile time
source\mod1.d(7,24):        called from here: `TranslatableString("Compile-time translation?").gettext()`
```

The solution is to remove the explicit `string` type and let the type of the constant be inferred:
```d
const statically_initialized = tr!"Compile-time translation!";
```

The correct translation will then be retrieved at the places where this constant is used, at run-time.

The way this works is that the type of the constant gets to be inferred as `TranslatableString`, a private struct inside the implementation of this package. Whenever an instance of this struct is evaluated, the value of the translation is retrieved.

## Added steps to the build process

With the `postBuildCommands` and `copyFiles` that you've added to your default Dub configuration, a couple of tasks are automated:
1. Translatable strings are extracted from the sources into a PO template.
1. Translations in any existing PO files are updated according to the new template.
1. PO files are converted into binary MO files.
1. MO files are copied to the target directory.

We'll discuss these in a little more detail below.

### Creating/updating the PO template automatically

In other languages, string extraction into a `.pot` file is done by invoking the `xgettext` tool from the GNU `gettext` utilities. Because `xgettext` does not know about all the string literal syntaxes in D, we emply D itself to perform this task.

This is how this works: The `dub run --config=xgettext` line in the  `postBuildCommands` section of your Dub configuration compiles and runs your project into an alternative `targetPath` and executes the code that you have mixed in at the top of your `main()` function. That code makes smart use of D language features to collect all strings that are to be translated, together with information from your Dub configuration and the latest Git tag. The rest of your `main()` is ignored in this configuration. In any other configuration the mixin is actually empty.

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
"Project-Id-Version: PACKAGE VERSION\n"
"Report-Msgid-Bugs-To: \n"
"POT-Creation-Date: 2022-06-19T17:02:56.6502103Z\n"
"PO-Revision-Date: YEAR-MO-DA HO:MI+ZONE\n"
"Last-Translator: FULL NAME <EMAIL@ADDRESS>\n"
"Language-Team: LANGUAGE <LL@li.org>\n"
"Language: \n"
"MIME-Version: 1.0\n"
"Content-Type: text/plain; charset=UTF-8\n"
"Content-Transfer-Encoding: 8bit\n"

#: source/mod1.d:11(fun1)
#, c-format
msgid "Hello! My name is %s."
msgstr ""

#: source/mod1.d:12(fun1) source/mod2.d:15(fun3)
msgid "Identical strings share their translation!"
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

The `"dub run gettext:merge -- --popath=po"` post-build command invokes the `merge` script that is included as a subpackage. This script runs the `msgmerge` utility from GNU `gettext` on the PO files that it finds. When needed, the path to `msgmerge` can be specified with the `--gettextpath` option. Any additional options are passed on to `msgmerge` directly, [see its documentation](https://www.gnu.org/software/gettext/manual/html_node/msgmerge-Invocation.html). For example, you can use the `--backup=numbered` option to keep backups of original translations.

Note that if translatable strings were changed in the source, or new ones were added, the PO file is now incomplete. This is detected by the script, which then prints a warning. Changed strings are marked as `#, fuzzy` in the PO file, which can be picked up by editors as needing work. If a lookup in an outdated MO file does not succeed, the application will show the string as it occurs in the source.

### Converting to binary form automatically

Similar to the previous step, the `"dub run gettext:po2mo -- --popath=po --mopath=mo"` post-build command invokes the `po2mo` subpackage, which runs the `msgfmt` utility from GNU `gettext`. This converts all PO files into MO files in the `mo` folder. This folder is then copied to the target directory for inclusion in the distribution of your package. Any additional options are passed on to `msgfmt` directly, [see its documentation](https://www.gnu.org/software/gettext/manual/html_node/msgfmt-Invocation.html).

## Adding translations

Each natural language that is going to be supported requires a `.po` file, which is derived from the generated `.pot` template file. This `.po` file is then edited to fill in the stubs with the correct translations.

There are various tools to do this, from dedicated stand-alone editors, editor plugins or modes, web applications to command line utilities.

Currently my presonal favourite is [Poedit](https://poedit.net/). You open the template, select the target language and start translating with real-time suggestions from various online translation engines. Or you let the AI give it its best effort and translate all messages at once, before reviewing the problematic ones (requires subscription). It supports marking translations that need work and adding notes to translations.

## Updating translations manually

Any translations that have fallen behind the template will need to be updated by a translator. To detect any such translations, you can scan for warnings in the output of this command:
```shell
dub run -q gettext:merge -- --popath=po
```

PO file editors will typically allow translators to quickly jump between strings that need their attention.

After a PO file has been edited, MO files must be regenerated with this command:
```shell
dub run gettext:po2mo -- --popath=po --mopath=mo
```

## Example

These are some runs of the included `teohdemo` test:
```shell
d:\SARC\gettext\tests\teohdemo>dub run -q
Please select a language:
[0] default
[1] en_GB
[2] nl_NL
[3] ru_RU
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
[3] ru_RU
3
Привет! Меня зовут Joe.
Я считаю 1 яблоко.
Привет! Меня зовут Schmoe.
Я считаю 3 яблока.
Привет! Меня зовут Jane.
Я считаю 5 яблок.
Привет! Меня зовут Doe.
Я считаю 7 яблок.
```
Notice how the translation of "apple" in the last translation changes with three different endings dependent on the number of apples.

# Credits

The idea for automatic string extraction came from H.S. Teoh [[1]](https://forum.dlang.org/post/mailman.2526.1585832475.31109.digitalmars-d@puremagic.com), [[2]](https://forum.dlang.org/post/mailman.4770.1596218284.31109.digitalmars-d-announce@puremagic.com), with optimizations by Steven Schveighoffer [[3]](https://forum.dlang.org/post/t8pqvg$20r0$1@digitalmars.com). Reading of MO files was implemented by Roman Chistokhodov.

# TODO

- Comments to translators, [proper names](https://www.gnu.org/software/gettext/manual/html_node/Names.html).
- Disambiguation with [contexts](https://www.gnu.org/software/gettext/manual/html_node/Contexts.html).
- Quotes inside WYSIWYG strings.
- Memoization. Make it optional through Dub configuration.
- Domains [[1]](https://www.gnu.org/software/gettext/manual/html_node/Triggering.html) and [Library support](https://www.gnu.org/software/gettext/manual/html_node/Libraries.html).
