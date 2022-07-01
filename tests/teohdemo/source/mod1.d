module mod1;

import std.stdio;
import gettext : gettext = tr; // Legacy GNU gettext format.

// Constants are supported. Their translation is retrieved when they are evaluated.
immutable hello = gettext!"Hello! My name is %s.";

void fun1(string name)
{
    writefln(hello, name);

    auto s = gettext!"Identical strings share their translation!";
}
