#!/usr/bin/env python3
"""Assemble reviewable engine license/source materials; not legal certification.

Usage: package-engine-compliance.py SOURCE ZIG OUTPUT KOOKOO_REPO
Only writes OUTPUT/EngineCompliance. SOURCE must be the actual patched build
source with fetched zig-pkg dependencies, not a source-only Git checkout.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import urllib.request

SIMDUTF_URL = "https://raw.githubusercontent.com/simdutf/simdutf/v9.0.0/LICENSE-MIT"
SIMDUTF_SHA256 = "fc8dbc04e03ad4efc08a647ffe7f995b811a95bc04c0e85a56d5277c6593fa5f"
FREETYPE = "N-V-__8AAKLKpwC4H27Ps_0iL3bPkQb-z6ZVSrB-x_3EEkub"
GETTEXT = "N-V-__8AADcZkgn4cMhTUpIz6mShCKyqqB-NBtf_S2bHaTC-"
JETBRAINS = "N-V-__8AAIC5lwAVPJJzxnCAahSvZTIlG-HhtOvnM1uh-66x"
NERDFONTS = "N-V-__8AAMVLTABmYkLqhZPLXnMl-KyN38R8UVYqGrxqO26s"
# Reviewed against the fixed Apple-silicon candidate. Broad scans below are a
# supplement, never a substitute for these easily-missed license filenames.
REQUIRED = [
    ("LICENSE", "Ghostty", "MIT", "engine"),
    (f"zig-pkg/{GETTEXT}/gettext-runtime/intl/COPYING.LIB", "gettext libintl", "LGPL-2.1", "statically linked library"),
    (f"zig-pkg/{GETTEXT}/COPYING", "gettext tools/source package", "GPL-3.0", "source-package supplement; not a claim Kookoo is GPL"),
    (f"zig-pkg/{FREETYPE}/LICENSE.TXT", "FreeType", "license-selection notice", "statically linked library"),
    (f"zig-pkg/{FREETYPE}/docs/FTL.TXT", "FreeType", "FTL (selected, not GPL alternative)", "statically linked library"),
    (f"zig-pkg/{FREETYPE}/src/bdf/README", "FreeType BDF driver", "file-specific notice", "source-package supplement"),
    (f"zig-pkg/{FREETYPE}/src/pcf/README", "FreeType PCF driver", "file-specific notice", "source-package supplement"),
    (f"zig-pkg/{JETBRAINS}/OFL.txt", "JetBrains Mono 2.304", "OFL-1.1", "embedded default font"),
    (f"zig-pkg/{NERDFONTS}/LICENSE", "Nerd Fonts Symbols Only 3.4.0", "mixed font licenses; see full text", "embedded symbols font"),
    ("src/font/res/README.md", "Ghostty font attribution index", "mixed; see index", "includes production and test fonts"),
    ("src/font/res/OFL.txt", "Ghostty font resources", "OFL-1.1", "resource/test-font supplement"),
    ("src/font/res/MIT.txt", "Ghostty font resources", "MIT", "resource/test-font supplement"),
    ("src/font/res/BSD-2-Clause.txt", "Ghostty font resources", "BSD-2-Clause", "resource/test-font supplement"),
]


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def require(path: Path) -> None:
    if not path.is_file() or path.stat().st_size == 0:
        raise RuntimeError(f"Required compliance input missing or empty: {path}")


def run(*args: str, cwd: Path) -> str:
    return subprocess.check_output(args, cwd=cwd, text=True).strip()


def make_source_archive(source: Path, target: Path, prefix: str, *, engine: bool) -> list[dict]:
    """Archive actual source, retaining nested manifests and fetched packages.

    Do not follow directory symlinks; retain safe relative symlinks as source.
    Exclude known root build products plus caches/.git at any depth. This does
    not exclude generic names such as 'build' or 'dist' inside dependencies,
    since those often contain necessary build scripts.
    """
    records = []
    root_outputs = {"zig-out", ".zig-cache", "zig-cache", ".build", "result"} if engine else set()
    def excluded(parts):
        return (any(p in {".git", ".zig-cache", "__pycache__"} for p in parts)
                or (parts and parts[0] in root_outputs)
                or (engine and len(parts) >= 2 and parts[:2] in [
                    ("macos", "GhosttyKit.xcframework"), ("macos", "build"),
                    ("macos", "DerivedData")]))
    with tarfile.open(target, "w:gz", dereference=False) as archive:
        for directory, dirs, files in os.walk(source, followlinks=False):
            base = Path(directory)
            dirs[:] = sorted(d for d in dirs if not excluded((base / d).relative_to(source).parts))
            names = sorted(files + [d for d in dirs if (base / d).is_symlink()])
            for name in names:
                path = base / name
                rel = path.relative_to(source)
                if excluded(rel.parts):
                    continue
                if path.is_symlink():
                    link = os.readlink(path)
                    resolved = (path.parent / link).resolve()
                    if Path(link).is_absolute() or not resolved.is_relative_to(source):
                        raise RuntimeError(f"External source symlink requires review: {rel} -> {link}")
                    records.append({"path": str(rel), "symlink": link})
                elif path.is_file():
                    records.append({"path": str(rel), "sha256": sha(path.read_bytes())})
                else:
                    raise RuntimeError(f"Unsupported source entry: {path}")
                archive.add(path, arcname=f"{prefix}/{rel}", recursive=False)
    return records


def package(source: Path, zig: Path, output: Path, repo: Path) -> Path:
    source, zig, output, repo = (p.resolve() for p in (source, zig, output, repo))
    destination = output / "EngineCompliance"
    if destination.exists():
        raise RuntimeError(f"Refusing to overwrite existing compliance package: {destination}")
    if output.is_relative_to(source) or output.is_relative_to(zig):
        raise RuntimeError("Output must be outside source/toolchain trees")
    for rel, *_ in REQUIRED:
        require(source / rel)
    # A license-only copy of zig-pkg must not pass as corresponding source.
    for rel in [f"zig-pkg/{GETTEXT}/gettext-runtime/intl/bindtextdom.c",
                f"zig-pkg/{FREETYPE}/src/base/ftbase.c", "pkg/libintl/build.zig",
                "pkg/libintl/config.h", "build.zig", "build.zig.zon",
                "pkg/simdutf/vendor/simdutf.h", "src/stb/stb_image.h",
                "src/stb/stb_image_resize.h"]:
        require(source / rel)
    require(zig / "LICENSE")
    if not (zig / "lib" / "std").is_dir() or not (zig / "lib" / "compiler_rt").is_dir():
        raise RuntimeError("Zig toolchain runtime source (lib/std and lib/compiler_rt) is missing")
    if '#define SIMDUTF_VERSION "9.0.0"' not in (source / "pkg/simdutf/vendor/simdutf.h").read_text():
        raise RuntimeError("simdutf version changed: review the pinned license before packaging")
    commit = run("git", "rev-parse", "HEAD", cwd=repo)
    if run("git", "status", "--porcelain", "--untracked-files=no", cwd=repo):
        raise RuntimeError("Kookoo tracked tree is dirty; git archive would not describe the built source")
    with urllib.request.urlopen(SIMDUTF_URL, timeout=30) as response:
        simd_license = response.read()
    if sha(simd_license) != SIMDUTF_SHA256:
        raise RuntimeError("Pinned simdutf license checksum mismatch")

    destination.mkdir(parents=True)
    licenses = destination / "licenses"
    manifests = []
    def copy_license(data: bytes, relative: str, component: str, license_name: str, scope: str):
        path = licenses / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        manifests.append({"path": str(path.relative_to(destination)), "sha256": sha(data),
                          "component": component, "license": license_name, "scope": scope})
    for rel, component, license_name, scope in REQUIRED:
        copy_license((source / rel).read_bytes(), f"required/{rel}", component, license_name, scope)
    copy_license(simd_license, "required/simdutf-9.0.0/LICENSE-MIT", "simdutf 9.0.0", "MIT (selected)", "vendored SIMD implementation")
    copy_license((zig / "LICENSE").read_bytes(), "required/zig-toolchain/LICENSE", "Zig toolchain/runtime", "see full text", "compiler/runtime source supplement")
    for name in ["stb_image.h", "stb_image_resize.h"]:
        data = (source / "src/stb" / name).read_text()
        marker = "This software is available under 2 licenses -- choose whichever you prefer."
        start = data.find(marker)
        if start < 0:
            raise RuntimeError(f"Expected embedded STB license marker missing: {name}")
        copy_license(data[start:].encode(), f"required/stb/{name}.license.txt", "STB " + name, "MIT selected; dual-license text retained", "compiled image implementation")
    # Preserve other fetched-package notices, but label as an unpruned superset.
    for path in sorted(source.rglob("*")):
        if not path.is_file() or path.is_symlink() or ".zig-cache" in path.parts:
            continue
        if path.name.lower().startswith(("license", "licence", "copying", "copyright", "notice")):
            rel = path.relative_to(source)
            copy_license(path.read_bytes(), f"supplement/{rel}", str(rel), "see full text", "unpruned source/build/test supplement")

    sources = destination / "sources"
    sources.mkdir()
    engine_manifest = make_source_archive(source, sources / "ghostty-patched-source.tar.gz", "ghostty-patched-source", engine=True)
    # Includes Zig's actual runtime/compiler support sources and headers. The
    # compiler executable is NOT copied; exact toolchain URL/hash is in builder.
    runtime_manifest = make_source_archive(zig / "lib", sources / "zig-runtime-sources.tar.gz", "zig-runtime-sources", engine=False)
    with open(sources / "kookoo-source.tar.gz", "wb") as file:
        subprocess.run(["git", "archive", "--format=tar.gz", "--prefix=kookoo-source/", commit], cwd=repo, stdout=file, check=True)
    (sources / "engine-source-manifest.json").write_text(json.dumps(engine_manifest, indent=2) + "\n")
    (sources / "zig-runtime-manifest.json").write_text(json.dumps(runtime_manifest, indent=2) + "\n")
    (destination / "license-manifest.json").write_text(json.dumps(manifests, indent=2) + "\n")
    (destination / "README.md").write_text(f'''# Engine license and corresponding-source review bundle

Built for Kookoo commit `{commit}`. This package records actual build inputs;
it is not legal certification and does not assert every supplementary license
applies to the shipping binary. Keep it alongside the exact engine binary,
SHA256SUMS and PROVENANCE.txt when publishing; do not use expiring Actions
artifacts as the permanent corresponding-source offer.

## Prominent third-party notice

Kookoo embeds Ghostty (MIT) and uses GNU gettext libintl, statically linked under
LGPL 2.1. The library and its use are covered by that license; its full text is in
`licenses/required/zig-pkg/{GETTEXT}/gettext-runtime/intl/COPYING.LIB`.
Recipients must be permitted to modify the work for their own use and reverse
engineer it for debugging those modifications. Do not add conflicting EULA or
anti-tampering terms. This notice does not change Kookoo's own MIT license.

Kookoo uses FreeType under the FreeType License (FTL), not its GPL alternative.
The FreeType Project's full license and attribution are included. Kookoo also
uses simdutf under MIT, STB under MIT, and embedded fonts under their individual
licenses. Preserve font copyright/reserved-name terms; fonts are not relicensed
as Kookoo's MIT code. `license-manifest.json` distinguishes required notices
from the conservative build/test/source supplement.

## Corresponding source and rebuild/relink route

1. Extract `sources/ghostty-patched-source.tar.gz` and `sources/kookoo-source.tar.gz`.
   The engine tree is the ACTUAL patched source used by the builder, including
   fetched `zig-pkg` source dependencies, nested build manifests, and libintl's
   build/configuration files. Do not apply the issue53 patch a second time.
2. Obtain the exact Zig toolchain from the URL/checksum pinned in Kookoo's
   `scripts/build-libghostty.sh`; use Apple silicon macOS and the Xcode/SDK
   identified in the matching PROVENANCE.txt. `sources/zig-runtime-sources.tar.gz`
   preserves compiler runtime/support sources, not the compiler executable.
3. In the extracted engine tree, change libintl under
   `zig-pkg/{GETTEXT}/gettext-runtime/intl` and/or `pkg/libintl`. Preserve its
   LGPL notices and clearly record modifications. Point the dependency at a
   local modified source path in `pkg/libintl/build.zig.zon` as needed; do not
   misrepresent changed source as matching an original content hash.
4. With the pinned `zig` on PATH, from the engine source run:
   ```sh
   zig build -Doptimize=ReleaseFast -Dsentry=false -Dversion-string=1.3.2-HEAD-+88c3325 -Demit-xcframework=true \\
     -Dxcframework-target=native -Demit-macos-app=false -Demit-docs=false
   ```
5. Copy the resulting `macos/GhosttyKit.xcframework` into the extracted Kookoo
   tree at `Vendor/GhosttyKit.xcframework`, without running the production
   download/setup script. Run `swift test --build-system native` followed by
   `bash scripts/build-app.sh` to relink the application against your modified
   library. The application supports local ad-hoc signing; no maintainer's
   Sparkle private key is required for this local build. Do not publish it as
   an official signed update or overwrite a user's running installation.

**Validation boundary:** the ordinary exact-source build was tested separately.
A modified-libintl relink must be tested and recorded before claiming this
route has been verified. Check the actual source manifests and shipping binary
inventory, retained notices, and durable download accessibility before release.
''')
    sums = []
    for path in sorted(destination.rglob("*")):
        if path.is_file():
            sums.append(f"{sha(path.read_bytes())}  {path.relative_to(destination)}")
    (destination / "SHA256SUMS").write_text("\n".join(sums) + "\n")
    return destination


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("source", "zig", "output", "repo"):
        parser.add_argument(name, type=Path)
    args = parser.parse_args()
    try:
        print(package(args.source, args.zig, args.output, args.repo))
    except (RuntimeError, OSError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"Engine compliance package incomplete: {error}\n")


if __name__ == "__main__":
    main()
