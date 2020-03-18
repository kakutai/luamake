
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

int main(int argc, char **argv) {

    /* Create VM state */
    lua_State *L = luaL_newstate();
    if (!L)
        return 1;
    luaL_openlibs(L); /* Open standard libraries */

	luaL_dostring(L, "require('luamake')");
    luaL_dostring(L, "arg = {}");

    char temp[256];
    for(int i=0; i<argc; i++) {
        sprintf(temp, "arg[%d]='%s'", i, argv[i]);
        luaL_dostring(L, temp);
    }

	luaL_dostring(L, "print('Running luamake...')");
	luaL_dostring(L, "runmain()");
	
    lua_settop(L, 0); /* (4) */
    
	lua_close(L);
	return 0;
}
