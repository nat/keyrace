CC=gcc
CFLAGS=-framework ApplicationServices -framework Carbon -Wall -g

all: keyrace

keyrace: keyrace.c
	gcc keyrace.c $(CFLAGS) -o keyrace

keyrace-server: $(wildcard *.go)
	go build -o $@ $?

test: $(wildcard *.go)
	@echo "Running the go tests..."
	go test $?
	@echo "Running the integration tests..."
	$(CURDIR)/integration-test.sh

clean:
	rm -rf keyrace keyrace.dSYM
