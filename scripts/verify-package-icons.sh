#!/usr/bin/env bash
# Check the actual mounted distribution, not only the staging app.
set -euo pipefail
DMG="${1:?usage: verify-package-icons.sh image.dmg}"
MOUNT="$(mktemp -d)"
cleanup() { hdiutil detach "$MOUNT" -quiet 2>/dev/null || true; rmdir "$MOUNT" 2>/dev/null || true; }
trap cleanup EXIT
hdiutil attach "$DMG" -mountpoint "$MOUNT" -readonly -nobrowse -quiet
APP="$MOUNT/Kookoo.app"
PLIST="$APP/Contents/Info.plist"
test "$(plutil -extract CFBundleIconFile raw "$PLIST")" = AppIcon.icns
if plutil -extract CFBundleIconName raw "$PLIST" >/dev/null 2>&1; then
    echo 'Unexpected asset-catalog icon key in standalone-ICNS app' >&2; exit 1
fi
test -s "$APP/Contents/Resources/AppIcon.icns"
test -s "$MOUNT/.VolumeIcon.icns"
cmp "$APP/Contents/Resources/AppIcon.icns" "$MOUNT/.VolumeIcon.icns"
ATTRS="$(xcrun GetFileInfo -a "$MOUNT")"
[[ "$ATTRS" == *C* ]] || { echo "Missing custom-icon volume flag: $ATTRS" >&2; exit 1; }
ICONSET="$(mktemp -d)/Verify.iconset"
iconutil -c iconset -o "$ICONSET" "$APP/Contents/Resources/AppIcon.icns"
test -s "$ICONSET/icon_512x512@2x.png"
rm -rf "$(dirname "$ICONSET")"
codesign --verify --deep --strict "$APP"
echo 'Verified mounted app ICNS, icon declaration, volume icon, custom-icon flag and signature.'
# Assessment is diagnostic only. Do not bypass or modify Gatekeeper policy.
spctl --assess --type execute --verbose "$APP" 2>&1 || true
