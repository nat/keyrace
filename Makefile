SERVER=keyrace.app

all:

keyrace-server: $(wildcard *.go)
	go mod vendor || true
	go build -o $@ $?

keyrace-server-linux: $(wildcard *.go)
	go mod vendor
	GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build \
	 -o $@ \
	 -a -tags "$(BUILDTAGS) static_build netgo" \
	 -installsuffix netgo -ldflags "-w -extldflags -static" $?;

test: $(wildcard *.go)
	sudo $(RM) $(TMPDIR)/keyrace.json /tmp/keyrace.json
	@echo "Running the go tests..."
	go mod vendor
	go test $?

deploy:
	scp server.go root@$(SERVER):

clean:
	rm -rf keyrace.dSYM
