#!/bin/sh
set -e

# Builds Pinger.app for macOS 26 (requires CLT 26.4+)

BUILD_DIR="${BUILD_DIR:-.}"

# Version: use $VERSION if set by CI (from git tag), otherwise generate from build time
VERSION="${VERSION:-$(date +%Y%m%d%H%M)}"
echo "let appVersion = \"$VERSION\"" > Sources/Pinger/Version.swift

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

# Copy Info.plist and icon, then stamp the version
cp Resources/Info.plist "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$CONTENTS/Info.plist"
mkdir -p "$CONTENTS/Resources"
cp Resources/Pinger.icns "$CONTENTS/Resources/Pinger.icns"

# Ad-hoc sign (no Developer ID — allows "Open Anyway" via System Settings)
codesign --deep --force --sign - "$APP"

# Remove old standalone binary if present
rm -f "$BUILD_DIR/Pinger"

echo "Built Pinger.app"
