SERVER=keyrace.app

keyrace-server: $(wildcard *.go)
	go mod vendor || true
	go build -o $@ $?

server: keyrace-server keyrace-server-linux ## Build the server.

keyrace-server-linux: $(wildcard *.go)
	go mod vendor
	GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build \
	 -o $@ \
	 -a -tags "$(BUILDTAGS) static_build netgo" \
	 -installsuffix netgo -ldflags "-w -extldflags -static" $?;

server-test: $(wildcard *.go)
	sudo $(RM) $(TMPDIR)/keyrace.json /tmp/keyrace.json
	@echo "Running the go tests..."
	go mod vendor
	go test $?

test: server-test ## Run the tests.

deploy: keyrace-server-linux ## Deploy the server binary.
	scp keyrace-server-linux $(SERVER):

clean:
	rm -rf keyrace.dSYM

.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | sed 's/^[^:]*://g' | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
