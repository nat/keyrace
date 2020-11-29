CC=gcc
CFLAGS=-framework ApplicationServices -framework Carbon -Wall -g

all: keyrace

keyrace: keyrace.c
	gcc keyrace.c $(CFLAGS) -o keyrace

clean:
	rm -rf keyrace keyrace.dSYM
