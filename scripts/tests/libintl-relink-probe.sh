#!/usr/bin/env bash
# Exercise recipient-side replacement from distributed corresponding source.
# Disposable macOS runner only; never publishes or changes an installed app.
set -euo pipefail
[[ "$(uname -s)" == Darwin && "$(uname -m)" == arm64 && "${GITHUB_ACTIONS:-}" == true ]]
MATERIALS="$(cd "${1:?EngineCompliance directory required}" && pwd)"
OUT="${2:?evidence output directory required}"
mkdir -p "$OUT"; OUT="$(cd "$OUT" && pwd)"
WORK=$(mktemp -d "${RUNNER_TEMP:-/tmp}/kookoo-relink.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
(cd "$MATERIALS" && shasum -a 256 -c SHA256SUMS) > "$OUT/material-verification.txt"
tar -xzf "$MATERIALS/sources/ghostty-patched-source.tar.gz" -C "$WORK"
tar -xzf "$MATERIALS/sources/kookoo-source.tar.gz" -C "$WORK"
curl --fail --show-error --location --proto '=https' --max-time 600 --retry 3 \
  https://ziglang.org/download/0.16.0/zig-aarch64-macos-0.16.0.tar.xz -o "$WORK/zig.tar.xz"
echo "b23d70deaa879b5c2d486ed3316f7eaa53e84acf6fc9cc747de152450d401489  $WORK/zig.tar.xz" | shasum -a 256 -c -
mkdir "$WORK/zig"; tar -xJf "$WORK/zig.tar.xz" -C "$WORK/zig" --strip-components=1
export PATH="$WORK/zig:$PATH" ZIG_GLOBAL_CACHE_DIR="$WORK/cache"
SOURCE="$WORK/ghostty-patched-source"
python3 - "$SOURCE" <<'PY'
import pathlib,re,sys
root=pathlib.Path(sys.argv[1]); ident='N-V-__8AADcZkgn4cMhTUpIz6mShCKyqqB-NBtf_S2bHaTC-'
p=root/'pkg/libintl/build.zig.zon'; s=p.read_text()
s,n=re.subn(r'\.gettext = \.\{.*?\n        \},', '.gettext = .{ .path = "../../zig-pkg/'+ident+'" },',s,count=1,flags=re.S)
assert n==1,'libintl dependency layout changed'
p.write_text(s)
p=root/'zig-pkg'/ident/'gettext-runtime/intl/bindtextdom.c'
assert p.is_file()
with p.open('a') as f:
    f.write('\n/* Kookoo recipient relink probe only; never a production patch. */\nint kookoo_libintl_relink_probe(void) { return 42; }\n')
PY
(cd "$SOURCE" && zig build --summary all -Doptimize=ReleaseFast -Demit-xcframework=true \
  -Dxcframework-target=native -Demit-macos-app=false -Demit-docs=false) 2>&1 | tee "$OUT/modified-engine-build.txt"
LIB="$SOURCE/macos/GhosttyKit.xcframework/macos-arm64/libghostty-internal.a"
nm -g "$LIB" 2>/dev/null | grep ' _kookoo_libintl_relink_probe$' > "$OUT/modified-library-symbol.txt"
cat > "$WORK/probe.c" <<'C'
#include <stdio.h>
extern int kookoo_libintl_relink_probe(void);
int main(void) { int n=kookoo_libintl_relink_probe(); printf("modified libintl marker=%d\n",n); return n==42?0:1; }
C
clang "$WORK/probe.c" "$LIB" -liconv -lc++ -framework CoreFoundation -o "$WORK/probe"
"$WORK/probe" | tee "$OUT/modified-library-execution.txt"
mkdir -p "$WORK/kookoo-source/Vendor"
cp -R "$SOURCE/macos/GhosttyKit.xcframework" "$WORK/kookoo-source/Vendor/"
(cd "$WORK/kookoo-source" && bash scripts/build-app.sh) 2>&1 | tee "$OUT/app-relink-build.txt"
codesign --verify --deep --strict "$WORK/kookoo-source/dist/Kookoo.app"
cat > "$OUT/RESULT.txt" <<'RESULT'
PASS: corresponding-source archives verified and extracted; libintl was modified
through a local source dependency, rebuilt into GhosttyKit, and its added marker
executed successfully in a linked test program. Kookoo was rebuilt/relinked
against that modified framework and passed strict code-sign verification using
local ad-hoc signing, without any maintainer private signing key.
This is technical relink evidence, not a legal compliance certification.
The modified framework/app are disposable test artifacts and are not published.
RESULT
cat "$OUT/RESULT.txt"
