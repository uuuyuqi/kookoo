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
