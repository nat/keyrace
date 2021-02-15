SERVER=keyrace.app

all:

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
	rm -rf keyrace.dSYM
