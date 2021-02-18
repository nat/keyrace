#!/bin/bash
set -eo pipefail
xcodebuild \
  -workspace mac/keyrace-mac.xcworkspace/ \
  -scheme keyrace-mac \
  -archivePath $PWD/build/keyrace.xcarchive \
  clean archive
