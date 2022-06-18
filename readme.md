# Gettext

This Dub package provides internationalization functionality that is compatible with the [GNU `gettext` utilities](https://www.gnu.org/software/gettext/). It combines convenient and reliable string extraction, enabled by D's unique language features, with existing well established utilities for translation into other natural languages. The resulting translation tables are loaded at run-time, allowing users to switch between natural languages within the same distribution. Many commercial translation offices support GNU `gettext` PO files (Portable Object), and various editors exist that help with the translation process. The translation process is completely separated from the programming process, so that they may happen asynchronously and without knowledge of eachother.

## Features

- Multiple identical strings are translated once.
- All marked strings that are seen by the compiler are extracted automatically.
- References to the source location of the original strings are maintained.
- Plural forms are supported and language-dependent.
- There are no dependencies on C libraries. There is an optional build-time dependency on the GNU `gettext` utilities for automated generation of MO files.

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
                "dub run gettext:po2mo -- --popath=po --mopath=mo"
            ],
            "copyFiles": [
                "mo"
            ]
        },
        {
            "name": "xgettext",
            "versions": [ "xgettext" ],
            "subConfigurations": {
                "gettext": "xgettext"
            }
        }
    ]
```

### `main` function

Insert the following line right above your `main` function:
```d
version (xgettext) {} else
```

### Source files

Prepend `_!` in front of every string literal that needs to be translated. For instance:
```d
    writeln(_!"This string is to be translated");
    writeln("This string will remain untranslated.");
```

Calls to `std.format` are to be replaced with `_!` like so:
```d
    format!"%d green bottles hanging on the wall"(n); // Before
    _!"%d green bottles hanging on the wall"(n);      // After
```

## Creating a PO Template

String extraction into a `.pot` file is traditionally done by invoking the `xgettext` tool from the `gettext` utilities. Instead, we do the same with a simple Dub invocation:
```shell
dub run --config=xgettext
```
This compiles and runs your project with an alternative `main` function provided by this package, which collects all strings to be translated, together with information from your Dub configuration and the latest Git tag.

By default this creates (or overwrites) the PO template in the `po` folder of your project. This can be changed by using options; To see which options are accepted, run the command with the `--help` option:
```shell
dub run --config=xgettext -- --help
```

### Example
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
"POT-Creation-Date: 2022-06-18T13:41:36.9820364Z\n"
"PO-Revision-Date: YEAR-MO-DA HO:MI+ZONE\n"
"Last-Translator: FULL NAME <EMAIL@ADDRESS>\n"
"Language-Team: LANGUAGE <LL@li.org>\n"
"Language: \n"
"MIME-Version: 1.0\n"
"Content-Type: text/plain; charset=UTF-8\n"
"Content-Transfer-Encoding: 8bit\n"

#: source/mod1.d:11(fun1)
", c-format
msgid "Hello! My name is %s."
msgstr ""

#: source/mod1.d:12(fun1) source/mod2.d:15(fun3)
msgid "Identical strings share their translation!"
msgstr ""

#: source/mod2.d:13(fun3)
msgid "Never used, but nevertheless translated!"
msgstr ""

#: source/mod2.d:8(fun2)
", c-format
msgid "I'm counting one apple."
msgid_plural "I'm counting %d apples."
msgstr[0] ""
msgstr[1] ""
```

## Adding translations

Each natural language that is going to be supported requires a `.po` file, which is derived from the previously generated `.pot` template file. This `.po` file is then edited to fill in the stubs with the correct translations. Lastly the `.po` is converted to binary `.mo` file (Machine Object) which is used for string lookup at run-time. Whenever the source code changes, the translations may need to be updated, which is done by comparing the old `.po` file with the new `.pot` file.

There are various tools to do this, from dedicated stand-alone editors, editor plugins or modes, web applications to command line utilities.

Currently my presonal favourite is [Poedit](https://poedit.net/). You open the template, select the target language and start translating with real-time suggestions from various online translation engines. It supports marking translations that need work and adding notes to translations.

If you have configured Dub as suggested above, the `.mo` files are generated as part of the build process and copied into the `mo` folder in the target path. It is best to configure your revision control system to ignore these files.

# Credits

The idea for automatic string extraction came from H.S. Teoh [[1]](https://forum.dlang.org/post/mailman.2526.1585832475.31109.digitalmars-d@puremagic.com), [[2]](https://forum.dlang.org/post/mailman.4770.1596218284.31109.digitalmars-d-announce@puremagic.com).

Reading of MO files was implemented by Roman Chistokhodov.
