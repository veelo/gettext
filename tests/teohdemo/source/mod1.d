module mod1;

import std.stdio;
import gettext;

// Statically initialized strings cannot be translated. Language is a run-time thing.
const const_s = "Identical strings share their translation!";

void fun1(string name)
{
    import std.format;

    writeln(format(tr!"Hello! My name is %s.", name));

    auto s = tr!const_s; // Defer translation of constants to run-time.
}
