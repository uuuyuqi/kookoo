#!/usr/bin/env python3
"""Refresh application correspondence without rebuilding the verified engine.

Usage: package-app-engine-materials.py ENGINE_COMPLIANCE OUTPUT [--repo PATH]
ENGINE_COMPLIANCE must come from the fixed, reviewed engine candidate, with its
framework archive and PROVENANCE.txt in the parent directory. Writes a new
OUTPUT directly; never edits inputs, publishes, or changes app pins.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import tempfile

ENGINE_SHA256 = "6bada6f5bf2e2105a1a5069dd705a1eafd6300a88fc19827e4b1fc53b0a58a10"
COMPLIANCE_SUMS_SHA256 = "a30c6f6132a36c30f8f2ac5e19ab2c789559f60e184df1132728d8dce55bf89b"
PROVENANCE_SHA256 = "967186db4b1aaf8f5f4bb49c05fa958a74405848c0a798f933eabfe008c8f199"
ENGINE_RUN = "https://github.com/uuuyuqi/kookoo/actions/runs/43598330698"
GETTEXT = "N-V-__8AADcZkgn4cMhTUpIz6mShCKyqqB-NBtf_S2bHaTC-"


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def verify_tree(root: Path) -> dict[str, str]:
    """Verify the exact reviewed input manifest, including absence of extra files."""
    manifest = root / "SHA256SUMS"
    if manifest.is_symlink() or digest(manifest) != COMPLIANCE_SUMS_SHA256:
        raise RuntimeError("Engine compliance manifest is not the fixed reviewed input")
    expected = {}
    for line in manifest.read_text().splitlines():
        match = re.fullmatch(r"([0-9a-f]{64})  (.+)", line)
        if not match:
            raise RuntimeError("Malformed compliance checksum entry")
        sha, name = match.groups()
        rel = PurePosixPath(name)
        if rel.is_absolute() or ".." in rel.parts or str(rel) != name or name in expected:
            raise RuntimeError(f"Unsafe or duplicate checksum path: {name}")
        path = root / name
        if not path.is_file() or path.is_symlink() or digest(path) != sha:
            raise RuntimeError(f"Engine compliance input mismatch: {name}")
        expected[name] = sha
    actual = set()
    for path in root.rglob("*"):
        if path.is_symlink():
            raise RuntimeError(f"Unexpected input symlink: {path}")
        if path.is_file() and path != manifest:
            actual.add(path.relative_to(root).as_posix())
    if actual != set(expected):
        raise RuntimeError("Compliance file inventory differs from the verified manifest")
    return expected


def git(repo: Path, *args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=repo, text=True).strip()


def package(compliance: Path, output: Path, repo: Path) -> Path:
    compliance, output, repo = (p.resolve() for p in (compliance, output, repo))
    destination = output
    if destination.exists():
        raise RuntimeError(f"Refusing to overwrite existing output: {destination}")
    if output.is_relative_to(compliance):
        raise RuntimeError("Output must not be inside the engine input directory")
    if git(repo, "status", "--porcelain", "--untracked-files=no"):
        raise RuntimeError("Tracked working tree/index is dirty; commit exact app inputs first")
    commit = git(repo, "rev-parse", "HEAD")
    info = git(repo, "show", "HEAD:Sources/KookyKit/App/AppInfo.swift")
    match = re.search(r'\bstatic let displayVersion\s*=\s*"([^"]+)"', info)
    if not match:
        raise RuntimeError("Cannot identify app version from committed AppInfo.swift")
    version = match.group(1)
    input_files = verify_tree(compliance)
    framework = compliance.parent / "GhosttyKit.xcframework.tar.gz"
    provenance = compliance.parent / "PROVENANCE.txt"
    for path, sha in [(framework, ENGINE_SHA256), (provenance, PROVENANCE_SHA256)]:
        if path.is_symlink() or digest(path) != sha:
            raise RuntimeError(f"Reviewed engine input mismatch: {path.name}")
    required = ["license-manifest.json", "sources/ghostty-patched-source.tar.gz",
                "sources/zig-runtime-sources.tar.gz", "sources/kookoo-source.tar.gz",
                f"licenses/required/zig-pkg/{GETTEXT}/gettext-runtime/intl/COPYING.LIB"]
    if any(name not in input_files for name in required):
        raise RuntimeError("Reviewed bundle is missing required notices or source materials")

    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".app-engine-materials-", dir=output.parent) as tmp:
        stage = Path(tmp) / "AppEngineMaterials"
        stage.mkdir()
        origin = stage / "engine-input-records"
        origin.mkdir()
        # Retain historical verification statements as historical, not the
        # current app instructions. Never mutate the reviewed input bundle.
        shutil.copy2(compliance / "SHA256SUMS", origin / "ORIGINAL-SHA256SUMS")
        shutil.copy2(compliance / "README.md", origin / "ORIGINAL-ENGINE-README.md")
        shutil.copy2(provenance, origin / "PROVENANCE.txt")
        for name in input_files:
            if name in {"README.md", "sources/kookoo-source.tar.gz"}:
                continue
            target = stage / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(compliance / name, target)
        app_archive = stage / "sources/kookoo-source.tar.gz"
        with app_archive.open("wb") as stream:
            subprocess.run(["git", "archive", "--format=tar.gz", "--prefix=kookoo-source/", commit], cwd=repo, stdout=stream, check=True)
        record = {
            "schema_version": 1,
            "application": {"name": "Kookoo", "version": version, "commit": commit,
                            "source_archive": "sources/kookoo-source.tar.gz",
                            "source_archive_sha256": digest(app_archive)},
            "engine": {"framework_sha256": ENGINE_SHA256, "reviewed_run": ENGINE_RUN,
                       "original_compliance_manifest_sha256": COMPLIANCE_SUMS_SHA256,
                       "provenance_sha256": PROVENANCE_SHA256,
                       "engine_source_archive_sha256": input_files["sources/ghostty-patched-source.tar.gz"]},
            "superseded_candidate_app_source_sha256": input_files["sources/kookoo-source.tar.gz"],
            "validation": "Packaging only; current-app relink/GUI/release checks must be recorded separately. No legal certification.",
        }
        (stage / "MATERIALS.json").write_text(json.dumps(record, indent=2) + "\n")
        (stage / "README.md").write_text(f'''# Kookoo {version}: engine notices and corresponding-source materials

Application commit: `{commit}`. Engine archive SHA256:
`{ENGINE_SHA256}`. See `MATERIALS.json` and `SHA256SUMS` for exact inputs.
This directory refreshes the application source only; the verified engine source,
licenses and runtime source archives are unchanged. The obsolete candidate app
snapshot is **not** included as the current application source.

## Third-party notice and recipient rights

Kookoo embeds Ghostty under MIT and statically links GNU gettext libintl under
LGPL 2.1. The library and its use are covered by that license; the full text is
`licenses/required/zig-pkg/{GETTEXT}/gettext-runtime/intl/COPYING.LIB`.
Recipients must be allowed to modify the work for their own use and reverse
engineer it to debug those modifications. Do not add conflicting restrictions.
This does not relicense Kookoo's own MIT code as GPL.

FreeType is used under FTL, not its alternative GPL license; its full terms and
attribution are retained. STB and simdutf use their MIT options. Fonts keep their
own copyright, OFL/reserved-name or other terms. `license-manifest.json` separates
required notices from a conservative source/build/test supplement; its extra GPL
texts do not imply that every included tool is linked into Kookoo.

## Rebuild the current app with a replaced static library

1. Extract `sources/ghostty-patched-source.tar.gz` and
   `sources/kookoo-source.tar.gz` into separate directories. The engine source
   already includes the issue53 patch and fetched dependency sources; do not
   apply it again. The app archive corresponds to commit `{commit}`.
2. Use Apple silicon macOS, the Xcode/SDK in `engine-input-records/PROVENANCE.txt`,
   and pinned Zig 0.16.0 from that record and `scripts/build-libghostty.sh`.
   `sources/zig-runtime-sources.tar.gz` retains runtime/compiler support sources.
3. Modify libintl at `zig-pkg/{GETTEXT}/gettext-runtime/intl` and/or
   `pkg/libintl`, preserving LGPL notices. Point the gettext dependency in
   `pkg/libintl/build.zig.zon` at that local source using `.path`; do not claim
   the changed source still matches the original content-addressed hash.
4. Build the changed engine with the pinned `zig` on PATH:
   ```sh
   zig build -Doptimize=ReleaseFast -Dsentry=false \\
     -Dversion-string=1.3.2-HEAD-+88c3325 -Demit-xcframework=true \\
     -Dxcframework-target=native -Demit-macos-app=false -Demit-docs=false
   ```
5. In the extracted app tree, create `Vendor/` and copy the resulting
   `macos/GhosttyKit.xcframework` to `Vendor/GhosttyKit.xcframework`.
   Do not run the production engine downloader over your replacement.
   Run `swift test --build-system native`, then
   `KOOKOO_ENGINE_COMPLIANCE_DIR=/absolute/path/to/these/materials bash scripts/build-app.sh`
   so notices are verified and installed before signing.
   Local ad-hoc builds do not require a maintainer's Sparkle private key.
   Preserve these notices in your redistributed app and publish its matching
   source/materials. A locally rebuilt app is not an official signed update.

## Verification and distribution boundary

This script verifies the reviewed input hashes and packages the exact current
app commit; it does not execute the current app or independently guarantee legal
compliance. Prior engine-build and modified-libintl relink evidence must not be
misrepresented as current-version app/GUI validation. Record fresh application
adoption checks separately. Historical engine documentation is retained unchanged
under `engine-input-records/`; it is not the current verification status.

Ship notices visibly in the app before signing and publish these source materials
alongside the matching binary at a durable location. An expiring Actions artifact
is not the permanent corresponding-source offer. Do not include source bundles in
an application update feed as if they were application versions.
''')
        sums = []
        for path in sorted(stage.rglob("*")):
            if path.is_file():
                sums.append(f"{digest(path)}  {path.relative_to(stage).as_posix()}")
        (stage / "SHA256SUMS").write_text("\n".join(sums) + "\n")
        # Recheck source identity after archiving, before exposing the output.
        if git(repo, "rev-parse", "HEAD") != commit or git(repo, "status", "--porcelain", "--untracked-files=no"):
            raise RuntimeError("App source changed during packaging; refusing mixed-version output")
        if destination.exists():
            raise RuntimeError("Output appeared concurrently; refusing overwrite")
        stage.rename(destination)
    return destination


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("compliance", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    try:
        print(package(args.compliance, args.output, args.repo))
    except (RuntimeError, OSError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"App/engine materials incomplete: {error}\n")


if __name__ == "__main__":
    main()
