# Gettext

This Dub package provides internationalization functionality that is compatible with the [GNU `gettext` utilities](https://www.gnu.org/software/gettext/). It combines convenient and reliable string extraction, enabled by D's unique language features, with existing well established utilities for translation into other natural languages. The resulting translation tables are loaded at run-time, allowing users to choose their preferred language. Many commercial translation offices support GNU `gettext` PO files (Portable Object), and various editors exist that help with the translation process. The translation process is completely separated from the programming process, so that they may happen asynchronously and without knowledge of eachother.

## Features

- Multiple identical strings are translated once.
- Extracts all marked strings that are seen by the compiler.
- Maintains references to the source location of the original string.
- Supports plural forms.

## Installation

### Dub configuration

Add the following to your `dub.json` (or its SDLang equivalent to your `dub.sdl`):

```json
    "dependencies": {
        "gettext": "*"
    },
    "configurations": [
        {
            "name": "default"
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
"POT-Creation-Date: 2022-06-17T21:58:39.6482118Z\n"
"PO-Revision-Date: YEAR-MO-DA HO:MI+ZONE\n"
"Last-Translator: FULL NAME <EMAIL@ADDRESS>\n"
"Language-Team: LANGUAGE <LL@li.org>\n"
"Language: \n"
"MIME-Version: 1.0\n"
"Content-Type: text/plain; charset=UTF-8\n"
"Content-Transfer-Encoding: 8bit\n"

#: source/mod1.d:8(fun1)
", c-format
msgid "Hello! My name is %s."
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

#: source/mod1.d:11 source/mod2.d:15(fun3)
msgid "Identical strings share their translation!"
msgstr ""
```

## Preparing PO files

Each natural language that is going to be supported requires a `.po` file, which is derived from the previously generated `.pot` template file. This can be done with the `msginit` utility distributed as part of the GNU `gettext` utilities, third party editors like [Poedit](https://poedit.net/), or by hand.

The `msginit` invocation is simple, for details please refer to the [`msginit` documentation](https://www.gnu.org/software/gettext/manual/html_node/msginit-Invocation.html).
```shell
cd po
msginit
```
Without options this creates the `en_GB.po` file for the British English language, in which all strings are copied verbatim (assuming the source strings are in English).

Use the `--locale` option for each new language that is to be supported, for example:
```shell
msginit --locale=ru_RU.UTF-8
```

# Credits

The idea for automatic string extraction came from H.S. Teoh [[1]](https://forum.dlang.org/post/mailman.2526.1585832475.31109.digitalmars-d@puremagic.com), [[2]](https://forum.dlang.org/post/mailman.4770.1596218284.31109.digitalmars-d-announce@puremagic.com).

Reading of MO files was implemented by Roman Chistokhodov.
