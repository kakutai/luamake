# luamake
A make tool built using luajit. 

Allows the execution of normal Makefiles as well as being about to be easily extended with Lua scripts.

Usage:
Use specific Makefile
```
luajit luamake.lua -f MakefileName 
```

Use default Makefile names - Makefile and makefile
```
luajit luamake.lua 
```

Use default internal build for a file named main.c
```
luajit luamake.lua main
```
Compiles main.c into main.o (this is default make behaviour).
Note: You must has environment variable CC set or set the CC value in the luamake.lua

The tool tries to conform to the correct operation specifications outlined in GNU Make:
https://pubs.opengroup.org/onlinepubs/009695399/utilities/make.html

This is the first pass. There will be more work on this as I use it in our company build systems.
