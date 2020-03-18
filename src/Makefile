

luamake: clean luamake_script.o   
	$(CC) -g -Wall -I../../luajit/src -o luamake luamake.c luamake_script.o -L../../luajit/src -lm -ldl -lluajit

luamake_script.o:
	luajit -b luamake.lua luamake_script.o

clean:
	rm -f luamake_script.o
	rm -f luamake 

.phony: clean luamake_script.o