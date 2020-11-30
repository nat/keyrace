CC=gcc
CFLAGS=-framework ApplicationServices -framework Carbon -Wall -g

all: keyrace

keyrace: keyrace.c
	gcc keyrace.c $(CFLAGS) -o keyrace

deploy:
	scp server.go root@159.89.136.69:

clean:
	rm -rf keyrace keyrace.dSYM

stop:
	killall -9 keyrace