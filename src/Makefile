
CC=gcc
CFLAGS=-g -Wall -Wl,-E

OBJS=lluamake.o
CFILES=luamake.c
OUTFILE=run_luamake

LUAFILES=../lua/luamake.lua

OBJDIRS=-I../../luajit/src
LIBDIRS=-L../../luajit/src

LIBS=-lm -ldl -lluajit

luamake: clean $(OBJS)    
	$(CC) $(CFLAGS) $(OBJDIRS) -o $(OUTFILE) $(CFILES) $(OBJS) $(LIBDIRS) $(LIBS)

$(OBJS):
	luajit -b $(LUAFILES) $(OBJS) 

clean:
	rm -f $(OBJS) 
	rm -f $(OUTFILE) 

.phony: clean $(OBJS) 