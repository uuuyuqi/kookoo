# Independent terminal engine: staged migration

Kookoo embeds GhosttyKit (libghostty). It does not launch or require a separately
installed Ghostty application. This work does **not** change that architecture.

## Current production engine

- Provider: iAmCorey/kooky release v0.50.5, `GhosttyKit.xcframework.tar.gz`.
- Archive SHA256: `fba19a549811a85323677660b35afa2e72cc81c58053669db94081e194c1e27e`.
- Claimed source lineage, now checked for patch applicability:
  `manaflow-ai/ghostty` commit `88c3325dc9698d887da7e07ee0f9b79c53020be2`
  plus `scripts/kooky-libghostty-issue53.patch`.
- Patch SHA256: `cd81f71d04b05f26abf38127e716f221324316ea6026e0c6823186a20fc94f39`.
- Source reports `1.3.2-dev`; this is NOT an official Ghostty stable release.
- Existing binary/source equivalence has not been independently established.

## Candidate controlled by Kookoo

`bash scripts/build-libghostty.sh` builds on an Apple silicon Mac. Its source
archive, patch and Zig 0.16.0 toolchain are hash pinned. Zig's transitive packages
are pinned by the source's `build.zig.zon` content hashes. The workflow is manually
runnable and also runs for changes to the isolated engine branch. There is no
scheduled upstream update, automatic promotion, secret access or release publish.

A portable preflight can run with `KOOKOO_ENGINE_PREFLIGHT_ONLY=1`. It verifies the
source archive and exact patch application only, not compilation or ABI safety.

Outputs include the framework archive, SHA256SUMS, provenance, patch, dependency
manifest and a conservative superset of dependency license notices. This is
source-controlled rebuilding, not a claim of byte-for-byte reproducible builds:
Xcode/SDK/runner images and build timestamps may affect output.

## Promotion gates (all still required)

1. Pass upstream ReleaseSafe tests, framework compilation and Kookoo Swift tests.
2. Verify app launch, rendering, IME, resize, alternate screen, pane splitting and
   rapid output on a Mac. Compare crash/issue53 regression behavior, not just build.
3. Check dependency licenses against the actual linked libraries and package the
   required notices into the shipping app. Ghostty's MIT text is retained in
   `licenses/Ghostty-MIT.txt`; transitive libraries may have different licenses.
4. Publish a reviewed engine asset and notices under **uuuyuqi/kookoo**, pin its
   actual archive SHA256 and new engine identity in setup-libghostty.sh, then run
   normal application CI and updater/package verification before a release.
5. Retain the last working engine pin for rollback. Never silently fall back to
   the old third-party release if the new checksum fails.

Until these gates pass, the default engine download remains unchanged. Copying
an old binary into our release is not equivalent to owning its build provenance.

## Configuration compatibility

Kookoo currently calls `ghostty_config_load_default_files`, then applies its own
baseline and `~/.kookoo/settings.json` overrides. A shared Ghostty default config
can therefore affect Kookoo (fonts, colors, key bindings, etc.); this does not mean
Ghostty.app is required. Updating Ghostty.app does not update Kookoo's embedded
engine. This migration intentionally keeps configuration precedence unchanged.
A future opt-out must be explicit and default-compatible, not silently sever
existing users' settings.

## Candidate validation record (2026-11-14)

- Builder commit: `7a179e09fce18158ad65e08265468ec408f866f2`.
- Successful run: https://github.com/uuuyuqi/kookoo/actions/runs/43589634422
- Source core tests: 86/86 build steps succeeded; 3336/3352 tests passed,
  16 skipped. These exclude the unrelated Ghostty.app frontend tests.
- Kookoo suite linked against the rebuilt engine: 1109 tests, 6 skipped,
  zero failures. Release app assembly and strict/deep code-sign verification
  succeeded. Ad-hoc signing is not Apple Developer ID signing or notarization.
- Candidate artifact: `14112572162` (`independent-engine-candidate`).
- Framework archive SHA256:
  `c3acd2217f76ad6cec03a07ce5350f56545cbd0919a45eec6fa5536334ae9df3`.
- Artifact downloaded separately and its SHA256SUMS verified.

This closes the automated build/test portion of promotion gate 1 only.
GUI smoke, complete shipping-notice reconciliation, durable engine release
publication, production pin change and normal release/updater checks remain.
Production download behavior has not changed. The Actions artifact expires;
it is not a suitable permanent production download URL.

## Privacy review of the pinned candidate

Sentry is compiled by default on macOS, but this is not automatic cloud telemetry.
At the pinned source, `pkg/sentry/build.zig` defaults to transport `none`,
`SharedDeps.zig` does not override it, and `src/crash/sentry.zig` installs a custom
transport that writes `.ghosttycrash` files locally. The built static archive
contains `sentry_transport_none.o`, not curl or WinHTTP transport objects.
This does not assert all of Kookoo is offline: update checking has its own network
behavior. Do not upload local crash reports without reviewing their contents.

The isolated macOS GUI probe passed in run
https://github.com/uuuyuqi/kookoo/actions/runs/43591884784 : actual shell execution,
ANSI/CJK/emoji display (screenshot reviewed), alternate-screen round trip,
5000-line scrollback and OSC-title propagation. Human IME composition and pane
resize/drag flows remain unverified. SwiftUI AttributeGraph cycle warnings were
observed without a crash; they have not been attributed to the engine.

## License/source packaging gate

The old filename-prefix scan is not a complete license package. The explicit
`package-engine-compliance.py` gate additionally requires FreeType FTL, font OFL,
STB embedded texts, simdutf 9.0.0 MIT, LGPL libintl notices and actual dependency
sources. It packages the patched engine tree (including fetched `zig-pkg` and
nested manifests), Zig runtime sources and corresponding Kookoo source, with
hashes and rebuild/relink instructions. Missing inputs fail the build.

libintl is statically linked under LGPL 2.1; merely labeling the engine MIT is
insufficient. Preserve modification/reverse-engineering rights and distribute
corresponding source/relink materials at the durable binary release location.
The explicit notice bundle still requires review against the shipped inventory,
and the modified-libintl relink route must be actually exercised before being
called verified. No production engine pin or configuration behavior is changed.
