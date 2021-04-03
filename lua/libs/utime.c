#include <stdio.h>
#include <sys/time.h>
#include <time.h>
#include <lua.h>
#include <lauxlib.h>

//微秒
static int getMicroSecond(lua_State *L) { 
    struct timeval tv; 
    gettimeofday(&tv, NULL); 
    long microsecond = tv.tv_sec*1000*1000 + tv.tv_usec; 
    lua_pushnumber(L, microsecond); 
    return 1;
}

//毫秒
static int getMilliSecond(lua_State *L) { 
    struct timeval tv;
    gettimeofday(&tv, NULL);
    long millisecond = (tv.tv_sec*1000*1000 + tv.tv_usec) / 1000;
    lua_pushnumber(L, millisecond); 
    return 1;
}

static const struct luaL_Reg utime_func[] = { 
    {"getMicroSecond", getMicroSecond}, 
    {"getMilliSecond", getMilliSecond}, 
    { NULL, NULL },
}; 

int luaopen_utime(lua_State *L) {
    //luaL_checkversion(L); 
    //luaL_newlib(L, lib);
    luaL_register(L, "bit", utime_func);
    return 1;
}
