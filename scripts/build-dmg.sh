#!/usr/bin/env bash
# Build a distributable DMG from dist/Kookoo.app — standard
# drag-to-Applications layout with /Applications symlink.
#
# Run scripts/build-app.sh first (or invoke this with --build to chain).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [ "${1:-}" = "--build" ]; then
    ./scripts/build-app.sh
fi

APP="dist/Kookoo.app"
[ -d "$APP" ] || {
    echo "build-dmg.sh: ${APP} not found. Run scripts/build-app.sh first (or pass --build)." >&2
    exit 1
}

VERSION="$(plutil -extract CFBundleShortVersionString raw "${APP}/Contents/Info.plist")"
DMG="dist/Kookoo-v${VERSION}.dmg"
STAGING="dist/dmg-staging"

echo "==> Staging ${APP} for DMG (v${VERSION})"
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

echo "==> Creating ${DMG} with a custom volume icon"
ICON="${APP}/Contents/Resources/AppIcon.icns"
[ -s "$ICON" ] || { echo "missing app icon: $ICON" >&2; exit 1; }
RW="dist/Kookoo-staging.dmg"
MOUNT="$(mktemp -d)"
cleanup() {
    hdiutil detach "$MOUNT" -quiet 2>/dev/null || true
    rmdir "$MOUNT" 2>/dev/null || true
    rm -f "$RW"
}
trap cleanup EXIT
hdiutil create -volname "Kookoo" -srcfolder "$STAGING" -ov -format UDRW "$RW" >/dev/null
hdiutil attach "$RW" -mountpoint "$MOUNT" -nobrowse -quiet
cp "$ICON" "$MOUNT/.VolumeIcon.icns"
xcrun SetFile -a V "$MOUNT/.VolumeIcon.icns"
xcrun SetFile -a C "$MOUNT"
hdiutil detach "$MOUNT" -quiet
hdiutil convert "$RW" -format UDZO -o "$DMG" >/dev/null

# Ad-hoc signing provides an integrity signature, not Developer ID trust
# or notarization. Managed devices and Gatekeeper may still block the image.
codesign --force --sign - "$DMG"

rm -rf "$STAGING"

SIZE="$(du -h "$DMG" | awk '{print $1}')"
echo ""
echo "✓ Built ${DMG} (${SIZE})"
echo "  open ${DMG}                # mount + see drag-to-install layout"
echo "  shasum -a 256 ${DMG}       # checksum for release notes"
