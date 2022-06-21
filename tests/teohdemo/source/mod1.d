module mod1;

import std.stdio;
import gettext;

// Constants are supported. Their translation is retrieved when they are evaluated.
immutable hello = tr!"Hello! My name is %s.";

void fun1(string name)
{
    writefln(hello, name);

    auto s = tr!"Identical strings share their translation!";
}
