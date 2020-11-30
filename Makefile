CC=gcc
CFLAGS=-framework ApplicationServices -framework Carbon -Wall -g
SERVER=159.89.136.69

all: keyrace

keyrace: keyrace.c
	gcc keyrace.c $(CFLAGS) -o keyrace

keyrace-server: $(wildcard *.go)
	go build -o $@ $?

test: $(wildcard *.go)
	sudo $(RM) $(TMPDIR)/keyrace.json /tmp/keyrace.json
	@echo "Running the go tests..."
	go mod vendor
	go test $?
	@echo "Running the integration tests..."
	$(CURDIR)/integration-test.sh

deploy:
	scp server.go root@$(SERVER):

clean:
	rm -rf keyrace keyrace.dSYM

stop:
	killall -9 keyrace

install: install-agent install-bitbar

install-bitbar:
	brew cask install bitbar
	mkdir -p ~/.bitbar
	defaults write com.matryer.BitBar pluginsDirectory "~/.bitbar"
	ln keyrace.1s.sh ~/.bitbar # hardlink, hopefully on the same filesystem
	open /Applications/BitBar.app
