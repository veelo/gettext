module mod1;

import std.stdio;
import gettext;

void fun1(string name)
{
    writeln(_!"Hello! My name is %s."(name));
}

const s = _!"Identical strings share their translation!";
