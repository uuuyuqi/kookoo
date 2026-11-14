#!/usr/bin/env bash
# Candidate engine builder: does NOT change the production engine pin or Vendor.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_SHA=88c3325dc9698d887da7e07ee0f9b79c53020be2
SOURCE_URL="https://codeload.github.com/manaflow-ai/ghostty/tar.gz/$SOURCE_SHA"
SOURCE_SHA256=ce47e588ae6b5e36caf263563040d2a89839b256db87d17cc163a8eb6bc3a6e1
PATCH_SHA256=cd81f71d04b05f26abf38127e716f221324316ea6026e0c6823186a20fc94f39
ZIG_VERSION=0.16.0
ZIG_URL=https://ziglang.org/download/0.16.0/zig-aarch64-macos-0.16.0.tar.xz
ZIG_SHA256=b23d70deaa879b5c2d486ed3316f7eaa53e84acf6fc9cc747de152450d401489
OUT="${1:-$ROOT/dist/engine-candidate}"
verify() {
  local actual
  actual=$(shasum -a 256 "$1" | awk '{print $1}')
  [[ "$actual" == "$2" ]] || { echo "Checksum mismatch: $1" >&2; exit 1; }
}
fetch() {
  curl --fail --show-error --location --proto '=https' --tlsv1.2 \
    --connect-timeout 15 --max-time 600 --retry 3 --output "$2" "$1"
}
verify "$ROOT/scripts/kooky-libghostty-issue53.patch" "$PATCH_SHA256"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/kookoo-engine.XXXXXX")
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/source"
fetch "$SOURCE_URL" "$TMP/source.tar.gz"
verify "$TMP/source.tar.gz" "$SOURCE_SHA256"
tar -xzf "$TMP/source.tar.gz" -C "$TMP/source" --strip-components=1
(cd "$TMP/source" && git apply --check "$ROOT/scripts/kooky-libghostty-issue53.patch" && git apply "$ROOT/scripts/kooky-libghostty-issue53.patch")
# Portable preflight verifies source and patch without executing upstream code.
if [[ "${KOOKOO_ENGINE_PREFLIGHT_ONLY:-0}" == 1 ]]; then
  echo "Verified pinned source archive and exact patch application. No build performed."
  exit 0
fi
[[ "$(uname -s)" == Darwin && "$(uname -m)" == arm64 ]] || {
  echo 'Full build requires an Apple silicon Mac with Xcode; use preflight on Linux.' >&2; exit 1;
}
xcodebuild -version
fetch "$ZIG_URL" "$TMP/zig.tar.xz"
verify "$TMP/zig.tar.xz" "$ZIG_SHA256"
mkdir "$TMP/zig"
tar -xJf "$TMP/zig.tar.xz" -C "$TMP/zig" --strip-components=1
[[ "$("$TMP/zig/zig" version)" == "$ZIG_VERSION" ]]
export PATH="$TMP/zig:$PATH"
export ZIG_GLOBAL_CACHE_DIR="$TMP/zig-cache"
(
  cd "$TMP/source"
  "$TMP/zig/zig" build test -Doptimize=ReleaseSafe -Dapp-runtime=none
  "$TMP/zig/zig" build -Doptimize=ReleaseFast -Demit-xcframework=true \
    -Dxcframework-target=native -Demit-macos-app=false -Demit-docs=false
)
[[ -d "$TMP/source/macos/GhosttyKit.xcframework" ]]
mkdir -p "$OUT/EngineLicenses"
cp "$TMP/source/LICENSE" "$OUT/EngineLicenses/Ghostty-MIT.txt"
# Preserve all bundled and fetched dependency notices. A superset is intentional;
# release review must reconcile these against the final linked dependency list.
python3 - "$TMP/source" "$ZIG_GLOBAL_CACHE_DIR" "$OUT/EngineLicenses" <<'PY'
import pathlib, shutil, sys
out=pathlib.Path(sys.argv[3])
for label, root in zip(('source', 'zig-cache'), map(pathlib.Path, sys.argv[1:3])):
    for p in root.rglob('*'):
        if p.is_file() and p.name.lower().startswith(('license', 'licence', 'copying', 'copyright', 'notice')):
            dest=out/label/p.relative_to(root)
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(p, dest)
PY
cp "$TMP/source/build.zig.zon" "$OUT/dependencies.zon"
cp "$ROOT/scripts/kooky-libghostty-issue53.patch" "$OUT/applied.patch"
cat > "$OUT/PROVENANCE.txt" <<INFO
Candidate only: not promoted to the Kookoo application engine.
Source: $SOURCE_URL
Source commit: $SOURCE_SHA
Source archive SHA256: $SOURCE_SHA256
Patch SHA256: $PATCH_SHA256
Zig: $ZIG_URL
Zig archive SHA256: $ZIG_SHA256
Target: native Apple silicon macOS; ReleaseFast engine; ReleaseSafe upstream tests.
Dependency content hashes: dependencies.zon
Build host: $(sw_vers -productVersion)
Xcode: $(xcodebuild -version | tr '\n' ' ')
Kookoo builder commit: $(git -C "$ROOT" rev-parse HEAD)
INFO
# Never overwrite production Vendor or publish a release in this script.
tar -czf "$OUT/GhosttyKit.xcframework.tar.gz" -C "$TMP/source/macos" GhosttyKit.xcframework
(cd "$OUT" && shasum -a 256 GhosttyKit.xcframework.tar.gz > SHA256SUMS)
echo "Candidate ready for integration and license review: $OUT"
