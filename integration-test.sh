#!/bin/bash
# To use this script just run it: ./integration-test.sh
set -o pipefail
set -e

# Build the server
echo "Building the server..."
make keyrace-server

SERVER_HOST=http://localhost:80

function finish {
	# There is no "pidof" command on a mac by default
	# so `brew install pidof`
	kill -15 $(pidof keyrace-server)
}

# Start the server
echo "Starting the server..."
( set -x; exec \
	./keyrace-server
	&> "server.log"
) &
# make sure that if the script exits unexpectedly, we stop this daemon we just started
trap finish EXIT

# Give the server a little time to come up so it's "ready"
tries=30
while ! curl $SERVER_HOST &> /dev/null; do
	(( tries-- ))
	if [ $tries -le 0 ]; then
		echo >&2 "error: server failed to start"
		echo >&2 "  check server.log for details"
		false
	fi
	sleep 2
done

# Run our tests.
echo "Running our tests..."
# Add a count for a user.
output=$(curl -s "${SERVER_HOST}/count?name=jess&count=12&team=default")
expected="updated count for jess from 0 to 12"
if [[ $output != $expected ]]; then
	echo >&2 "expected: $expected; got: $output"
	exit 1
fi
# Make sure we got the count.
output=$(curl -s "${SERVER_HOST}/?team=default")
expected="jess                12	Less than a second"
if [[ "$output" != *"jess"* ]]; then
	echo >&2 "expected: $expected; got: $output"
	exit 1
fi
# Add more to our count.
output=$(curl -s "${SERVER_HOST}/count?name=jess&count=124&team=default")
expected="updated count for jess from 12 to 124"
if [[ $output != $expected ]]; then
	echo >&2 "expected: $expected; got: $output"
	exit 1
fi
# Make sure we got the count.
output=$(curl -s "${SERVER_HOST}/?team=default")
expected="jess	124	Less than a second"
if [[ $output != $expected ]]; then
	echo >&2 "expected: $expected; got: $output"
	exit 1
fi
# Add another player to the team
output=$(curl -s "${SERVER_HOST}/count?name=billy&count=999&team=default")
expected="updated count for billy from 0 to 999"
if [[ $output != $expected ]]; then
	echo >&2 "expected: $expected; got: $output"
	exit 1
fi
# Make sure we got the count.
output=$(curl -s "${SERVER_HOST}/?team=default")
expected=$(cat <<-END
billy	999	Less than a second
jess	124	Less than a second
END
)
if [[ $output != $expected ]]; then
	echo >&2 "expected: $expected; got: $output"
	exit 1
fi
