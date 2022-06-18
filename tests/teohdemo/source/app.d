import std.conv : to;
import mod1, mod2;

version (xgettext) {} else
void main()
{
    foreach (i, name; ["Joe", "Schmoe", "Jane", "Doe"])
    {
        fun1(name);
        fun2(1 + i.to!int * 2);
    }
}
