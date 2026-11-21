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
CHOICES="$APP/Contents/Resources/IconChoices"
cmp "$APP/Contents/Resources/AppIcon.icns" "$CHOICES/default.icns"
EXPECTED_IDS=(
    default 01-pearl 02-marshmallow 03-neon 04-retro 05-ink 06-jelly 07-chrome 08-pixel 09-hacker 10-swiss
    11-porcelain 12-sunset 13-velvet 14-space 15-noir 16-ocean 17-bauhaus 18-peach 19-graphite 20-prism
)
for ((number=1; number<=40; number++)); do
    EXPECTED_IDS+=("$(printf 'review-%02d' "$number")")
done
if ! diff -u <(printf './%s.icns\n' "${EXPECTED_IDS[@]}" | LC_ALL=C sort) \
    <(cd "$CHOICES" && find . -type f -name '*.icns' -print | LC_ALL=C sort); then
    echo 'Incorrect mounted app icon filenames' >&2; exit 1
fi
for id in "${EXPECTED_IDS[@]}"; do
    test -s "$CHOICES/$id.icns" || { echo "Empty mounted icon: $id.icns" >&2; exit 1; }
done
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
