SERVER=keyrace.app

all:

keyrace-server: $(wildcard *.go)
	go mod vendor
	go build -o $@ $?

test: $(wildcard *.go)
	sudo $(RM) $(TMPDIR)/keyrace.json /tmp/keyrace.json
	@echo "Running the go tests..."
	go mod vendor
	go test $?

deploy:
	scp server.go root@$(SERVER):

clean:
	rm -rf keyrace.dSYM
