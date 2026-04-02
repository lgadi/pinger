#!/bin/sh
set -e

# Builds Pinger.app for macOS 26 (requires CLT 26.4+)

BUILD_DIR="${BUILD_DIR:-.}"

APP="$BUILD_DIR/Pinger.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"

# Clean previous bundle
rm -rf "$APP"
mkdir -p "$MACOS"

# Compile
swiftc \
  -strict-concurrency=minimal \
  Sources/Pinger/*.swift \
  -framework AppKit \
  -framework SystemConfiguration \
  -lsqlite3 \
  -o "$MACOS/Pinger"

# Copy Info.plist and icon
cp Resources/Info.plist "$CONTENTS/Info.plist"
mkdir -p "$CONTENTS/Resources"
cp Resources/Pinger.icns "$CONTENTS/Resources/Pinger.icns"

# Remove old standalone binary if present
rm -f "$BUILD_DIR/Pinger"

echo "Built Pinger.app"
