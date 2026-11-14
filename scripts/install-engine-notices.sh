#!/usr/bin/env bash
# Used before application signing; source materials accompany the distribution.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MATERIALS="${1:?EngineCompliance directory required}"
DEST="${2:?App Resources directory required}"
(cd "$MATERIALS" && shasum -a 256 -c SHA256SUMS)
test -d "$MATERIALS/licenses"
test -f "$MATERIALS/license-manifest.json"
test ! -e "$DEST/EngineLicenses"
mkdir -p "$DEST/EngineLicenses"
cp -R "$MATERIALS/licenses" "$DEST/EngineLicenses"
cp "$MATERIALS/license-manifest.json" "$DEST/EngineLicenses/manifest.json"
cp "$ROOT/licenses/ENGINE-NOTICE.md" "$DEST/EngineThirdPartyNotices.md"
