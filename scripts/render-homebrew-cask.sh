#!/usr/bin/env bash
# Render a release cask without changing or publishing the Homebrew tap.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DMG="${1:?usage: render-homebrew-cask.sh dist/Kookoo-vX.Y.Z.dmg [--local-test]}"
[[ -f "$DMG" ]]
filename="${DMG##*/}"
[[ "$filename" =~ ^Kookoo-v([0-9]+[.][0-9]+[.][0-9]+)[.]dmg$ ]] || { echo "Unexpected DMG filename" >&2; exit 1; }
version="${BASH_REMATCH[1]}"
hash="$(shasum -a 256 "$DMG" | cut -d ' ' -f 1)"
[[ "$hash" =~ ^[[:xdigit:]]{64}$ ]]
case "${2:-}" in
    "") url="https://github.com/uuuyuqi/kookoo/releases/download/v$version/$filename" ;;
    --local-test)
        [[ "${GITHUB_ACTIONS:-}" == true ]] || { echo "Local test is for the disposable CI runner only" >&2; exit 1; }
        directory="$(cd "$(dirname "$DMG")" && pwd -P)"
        [[ "$directory" =~ ^/[a-zA-Z0-9/_.-]+$ ]] || { echo "Unsafe fixture path" >&2; exit 1; }
        url="file://$directory/$filename"
        ;;
    *) echo "Unknown option" >&2; exit 2 ;;
esac
sed -e "s|@VERSION@|$version|g" -e "s|@SHA256@|$hash|g" -e "s|@URL@|$url|g" "$ROOT/packaging/homebrew/kookoo.rb.in"
