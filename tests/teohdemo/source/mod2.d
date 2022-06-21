module mod2;

import std.stdio;
import gettext : _ = tr;    // Customary in GNU software.

void fun2(int num)
{
    writeln(_!("I'm counting one apple.", "I'm counting %d apples.")(num));
}

void fun3()
{
    writeln(_!"Never used, but nevertheless translated!");
    writeln("This string will remain untranslated.");
    writeln(_!"Identical strings share their translation!");
}
