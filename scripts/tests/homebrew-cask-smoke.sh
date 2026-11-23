#!/usr/bin/env bash
# Install/uninstall the actual CI-built DMG without publishing any tap or
# changing system policy. Do not run this against a user's Homebrew.
set -euo pipefail
[[ "$(uname -s)" == Darwin && "${GITHUB_ACTIONS:-}" == true ]]
DMG="${1:?expected release DMG}"
TMP="$(mktemp -d "${RUNNER_TEMP:-/tmp}/kookoo-brew.XXXXXX")"
TAP="kookoo-fixture/local"
export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ANALYTICS=1
mkdir -p "$TMP/tap/Casks" "$TMP/Applications"
git -C "$TMP/tap" init -q
bash scripts/render-homebrew-cask.sh "$DMG" --local-test > "$TMP/tap/Casks/kookoo.rb"
git -C "$TMP/tap" add Casks/kookoo.rb
git -C "$TMP/tap" -c user.name=Kookoo -c user.email=ci@example.invalid commit -qm 'Local CI fixture'
brew tap kookoo-fixture/local "$TMP/tap"
cleanup() { brew uninstall --cask "$TAP/kookoo" >/dev/null 2>&1 || true; brew untap kookoo-fixture/local >/dev/null 2>&1 || true; rm -rf "$TMP"; }
trap cleanup EXIT
brew install --cask --appdir="$TMP/Applications" "kookoo-fixture/local/kookoo"
app="$TMP/Applications/Kookoo.app"
test -d "$app"
codesign --verify --deep --strict "$app"
version="${DMG##*Kookoo-v}"; version="${version%.dmg}"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist")" = com.uuuyuqi.kookoo
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")" = "$version"
lipo -verify_arch arm64 "$app/Contents/MacOS/Kookoo"
brew uninstall --cask "kookoo-fixture/local/kookoo"
test ! -e "$app"
echo "PASS: exact packaged DMG installed and uninstalled through a temporary Homebrew cask"
