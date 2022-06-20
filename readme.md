# Gettext

This Dub package provides internationalization functionality that is compatible with the [GNU `gettext` utilities](https://www.gnu.org/software/gettext/). It combines convenient and reliable string extraction, enabled by D's unique language features, with existing well established utilities for translation into other natural languages. The resulting translation tables are loaded at run-time, allowing users to switch between natural languages within the same distribution. Many commercial translation offices support GNU `gettext` message catalogs (the PO files, for Portable Object), and various editors exist that help with the translation process. The translation process is separated from the programming process, so that they may happen asynchronously and without knowledge of eachother.

## Features

- Multiple identical strings are translated once.
- All marked strings that are seen by the compiler are extracted automatically.
- Supports listing unmarked strings in the project.
- References to the source location of the original strings are maintained.
- Plural forms are supported and language dependent.
- No dependencies on C libraries, platfom independent.
- Automated generation of the PO template.
- Automated merging into existing translations (requires [GNU `gettext` utilities](https://www.gnu.org/software/gettext/)).
- Automated generation of MO files (Machine Object) (requires [GNU `gettext` utilities](https://www.gnu.org/software/gettext/)).
- Runtime language discovery and selection.

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
                "dub run gettext:merge -- --popath=po",
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

### `main` function

Insert the following line right above your `main` function:
```d
version (xgettext) {} else
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

Prepend `_!` in front of every string literal that needs to be translated. For instance:
```d
    writeln(_!"This string is to be translated");
    writeln("This string will remain untranslated.");
```

Calls to `std.format` are to be replaced with `_!` also. To properly handle plural forms, supply both the singular and plural form like this:
```d
    // Before:
    format!"%d green bottles hanging on the wall"(n);
    // After:
    _!("one green bottle hanging on the wall",
       "%d green bottles hanging on the wall")(n);
```
Note that the format specifier (`%d`, or `%s`, etc.) is optional in the singular form.

### Finding unmarked strings

To get an overview of all string literals in your project that are not marked as translatable, execute the following in your project root folder:
```shell
dub run gettext:todo -q
```
This prints a list of strings with their source file names and row numbers.

### Compiler errors

Beware that string literals used for static initialization cannot be marked as translatable. Since the language can be changed at run time, string values cannot be evaluated at compile time.

For example, changing this line in `tests\teohdemo\source\mod1.d`
```d
const const_s = "Identical strings share their translation!";
```
into
```d
const const_s = _!"Identical strings share their translation!";
```
will produce this error:
```shell
gettext.d(201,23): Error: static variable `currentLanguage` cannot be read at compile time
gettext.d(201,22):        called from here: `format(currentLanguage.gettext("Identical strings share their translation!"))`
mod1.d(7,17):        called from here: `_()`
```
The solution, as demonstrated by the example, is to translate the string everywhere this constant is used, like
```d
_!const_s
```


## Added steps to the build process

With the `postBuildCommands` and `copyFiles` that you've added to your default Dub configuration, a couple of tasks are automated:
1. Translatable strings are extracted from the sources into a PO template.
1. Translations in any existing PO files are updated according to the new template.
1. PO files are converted into binary MO files.
1. MO files are copied to the target directory.

We'll discuss these in a little more detail below.

### Creating/updating the PO template automatically

In other languages, string extraction into a `.pot` file is done by invoking the `xgettext` tool from the GNU `gettext` utilities. Because `xgettext` does not know about all the string literal syntaxes in D, we emply D itself to perform this task.

This is how this works: The `dub run --config=xgettext` line in the  `postBuildCommands` section of your Dub configuration compiles and runs your project into an alternative `targetPath` with an alternative `main` function provided by this package. That code makes smart use of D language features to collect all strings that are to be translated, together with information from your Dub configuration and the latest Git tag.

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

The `"dub run gettext:merge -- --popath=po"` post-build command invokes the `merge` script that is included as a subpackage. This script runs the `msgmerge` utility from GNU `gettext` on the PO files that it finds. When needed, the path to `msgmerge` can be specified with the `--gettextpath` option. Any additional options are passed on to `msgmerge` directly, [see its documentation](https://www.gnu.org/software/gettext/manual/html_node/msgmerge-Invocation.html). For example, you can add the `--backup=numbered` option to keep backups of original translations.

Note that if translatable strings were changed in the source, or new ones were added, the PO file is now incomplete. This is detected by the script, which then prints a warning. Changed strings are marked as `#, fuzzy` in the PO file, which can be picked up by editors as needing work. If a lookup in an outdated MO file does not succeed, the application will show the string as it occurs in the source.

### Converting to binary form automatically

Similar to the previous step, the `"dub run gettext:po2mo -- --popath=po --mopath=mo"` post-build command invokes the `po2mo` subpackage, which runs the `msgfmt` utility from GNU `gettext`. This converts all PO files into MO files in the `mo` folder. This folder is then copied to the target directory for inclusion in the distribution of your package. Any additional options are passed on to `msgfmt` directly, [see its documentation](https://www.gnu.org/software/gettext/manual/html_node/msgfmt-Invocation.html).

## Adding translations

Each natural language that is going to be supported requires a `.po` file, which is derived from the generated `.pot` template file. This `.po` file is then edited to fill in the stubs with the correct translations.

There are various tools to do this, from dedicated stand-alone editors, editor plugins or modes, web applications to command line utilities.

Currently my presonal favourite is [Poedit](https://poedit.net/). You open the template, select the target language and start translating with real-time suggestions from various online translation engines. It supports marking translations that need work and adding notes to translations.

## Updating translations

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

The idea for automatic string extraction came from H.S. Teoh [[1]](https://forum.dlang.org/post/mailman.2526.1585832475.31109.digitalmars-d@puremagic.com), [[2]](https://forum.dlang.org/post/mailman.4770.1596218284.31109.digitalmars-d-announce@puremagic.com).

Reading of MO files was implemented by Roman Chistokhodov.

# TODO

- Comments to translators, [proper names](https://www.gnu.org/software/gettext/manual/html_node/Names.html).
- Disambiguation with [contexts](https://www.gnu.org/software/gettext/manual/html_node/Contexts.html).
- Quotes inside WYSIWYG strings.
- Memoization. Make it optional through Dub configuration.
- Domains [[1]](https://www.gnu.org/software/gettext/manual/html_node/Triggering.html) and [Library support](https://www.gnu.org/software/gettext/manual/html_node/Libraries.html).

