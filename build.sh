#!/bin/sh
# Builds dist/Talkback.app, signed ad hoc.
set -e
cd "$(dirname "$0")"

swift build -c release
APP=dist/Talkback.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/Talkback "$APP/Contents/MacOS/Talkback"
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
echo "Built $APP"
