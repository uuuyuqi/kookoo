#!/bin/bash
# Exercise the actual published HTTPS feed + production-signed archive on CI.
# No private key, no user Mac, no /Applications changes, no policy bypass.
set -euo pipefail
[[ "$(uname -s)" == Darwin && "${CI:-}" == true ]]
DMG="$1"; EXPECTED="$2"
WORK="$(mktemp -d "${RUNNER_TEMP:-/tmp}/kookoo-production-upgrade.XXXXXX")"
MOUNT="$WORK/mount";mkdir -p "$MOUNT"
cleanup() { hdiutil detach "$MOUNT" -quiet 2>/dev/null || true; rm -rf "$WORK"; }
trap cleanup EXIT
hdiutil attach "$DMG" -mountpoint "$MOUNT" -readonly -nobrowse -quiet
ditto "$MOUNT/Kookoo.app" "$WORK/Kookoo.app"
cp "$MOUNT/Kookoo.app/Contents/MacOS/Kookoo" "$WORK/expected-executable"
hdiutil detach "$MOUNT" -quiet
# Make an older isolated baseline with the shipped trust anchor. This is not
# an assertion that previously shipped, unconfigured 0.1.2 can self-update.
/usr/libexec/PlistBuddy -c 'Set :CFBundleVersion 0.1.2' "$WORK/Kookoo.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleShortVersionString 0.1.2' "$WORK/Kookoo.app/Contents/Info.plist"
codesign --force --sign - "$WORK/Kookoo.app"
git clone --quiet --depth 1 --branch 2.10.1 https://github.com/sparkle-project/Sparkle.git "$WORK/Sparkle"
[[ "$(git -C "$WORK/Sparkle" rev-parse HEAD)" == ab7d71291238df6e0492143b120c9b696a35f603 ]]
xcodebuild -project "$WORK/Sparkle/Sparkle.xcodeproj" -scheme sparkle-cli -configuration Release -derivedDataPath "$WORK/derived" CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual ONLY_ACTIVE_ARCH=YES build > "$WORK/build.log" 2>&1 || { tail -60 "$WORK/build.log"; exit 1; }
CLI="$WORK/derived/Build/Products/Release/sparkle.app/Contents/MacOS/sparkle"
# CLI must accept the preview channel, just as the application's delegate does.
python3 - "$CLI" "$WORK/Kookoo.app" <<'PY'
import subprocess,sys
p=subprocess.run([sys.argv[1],sys.argv[2],'--check-immediately','--grant-automatic-checks','--feed-url','https://raw.githubusercontent.com/uuuyuqi/kookoo/main/appcast.xml','--channels','preview','--user-agent-name','Kookoo-Production-Feed-CI','--verbose'],timeout=180)
raise SystemExit(p.returncode)
PY
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$WORK/Kookoo.app/Contents/Info.plist")" = "$EXPECTED"
test "$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$WORK/Kookoo.app/Contents/Info.plist")" = "$(cat config/sparkle-public-key.txt)"
cmp "$WORK/expected-executable" "$WORK/Kookoo.app/Contents/MacOS/Kookoo"
codesign --verify --deep --strict "$WORK/Kookoo.app"
echo 'PASS: actual published feed and production-signed archive installed through Sparkle into isolated old-version fixture.'
