#!/bin/sh
set -e

# Build the app first
./build.sh

VOLUME_NAME="Pinger"
DMG_FINAL="Pinger.dmg"
DMG_TMP="Pinger-tmp.dmg"

# Clean up any previous artifacts
rm -f "$DMG_FINAL" "$DMG_TMP"

# Staging folder: app + Applications symlink
STAGING=$(mktemp -d)
cp -R Pinger.app "$STAGING/"
ln -s /Applications "$STAGING/Applications"

# Create a read-write DMG from the staging folder
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDRW \
    "$DMG_TMP"

rm -rf "$STAGING"

# Mount it (suppress auto-open)
MOUNTPOINT=$(hdiutil attach -readwrite -noverify -noautoopen "$DMG_TMP" \
    | awk 'END { print $NF }')

# Customise the Finder window via AppleScript
osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 100, 880, 380}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 80
        set position of item "Pinger.app"    of container window to {160, 140}
        set position of item "Applications"  of container window to {400, 140}
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
APPLESCRIPT

# Unmount
hdiutil detach "$MOUNTPOINT"

# Convert to compressed, read-only DMG
hdiutil convert "$DMG_TMP" -format UDZO -imagekey zlib-level=9 -o "$DMG_FINAL"
rm -f "$DMG_TMP"

echo "Created $DMG_FINAL"
