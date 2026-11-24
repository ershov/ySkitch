#!/bin/bash
# Builds a release ySkitch.app into ./build.
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="ySkitch"
OUT_DIR="build"
APP="$OUT_DIR/$APP_NAME.app"

swift build -c release --product "$APP_NAME"
BIN_DIR="$(swift build -c release --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
plutil -replace CFBundleShortVersionString -string "$(./version.sh version)" "$APP/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$(./version.sh build)" "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist" >/dev/null
codesign --force --sign - --timestamp=none "$APP"

echo "Built $APP $(./version.sh full)"
