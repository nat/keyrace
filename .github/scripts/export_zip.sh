#!/bin/bash
set -eo pipefail
cp -r build/keyrace.xcarchive/Products/Applications/keyrace-mac.app build
cd build
zip -vr keyrace.zip keyrace-mac.app
