SERVER=keyrace.app
BUILDTAGS=libsqlite3 sqlite_omit_load_extension

keyrace-server: $(wildcard *.go)
	go mod vendor || true
	go build -o $@ \
		-tags "$(BUILDTAGS)" $?

server: keyrace-server keyrace-server-linux ## Build the server.

keyrace-server-linux: $(wildcard *.go)
	# On a mac you need to `brew install sqlite`
	echo "Using sqlite broke the static binary building on macos"
	#go mod vendor
	#GOOS=linux GOARCH=amd64 CGO_ENABLED=1 go build \
	# -o $@ \
	# -tags "$(BUILDTAGS)" \
	# -installsuffix netgo -ldflags "-w -extldflags" $?

keyrace-mac:
	set -eo pipefail
	mkdir -p build/mac
	xcodebuild \
		-workspace mac/keyrace-mac.xcworkspace/ \
		-scheme keyrace-mac \
		-archivePath $(PWD)/build/keyrace.xcarchive \
		clean archive
	cp -r build/keyrace.xcarchive/Products/Applications/keyrace-mac.app build/mac

server-test: $(wildcard *.go)
	@echo "Running the go tests..."
	go mod vendor
	go test $?

test: server-test ## Run the tests.

deploy: keyrace-server-linux ## Deploy the server binary.
	scp keyrace-server-linux $(SERVER):

clean:
	rm -rf keyrace.dSYM

.PHONY: help
help: ## Show this help.
	@fgrep -h "##" $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/\\$$//' | sed -e 's/##//'
