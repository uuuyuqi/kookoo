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

## Completed material and recipient verification (2026-11-14)

The complete license/source candidate passed:
https://github.com/uuuyuqi/kookoo/actions/runs/43592553561

- Framework archive SHA256:
  `2c1428e1dbbe25a688b6ea633631f21d86ff57467161a0996b3ef9db2398bff4`.
- Artifact `14113498517` includes actual patched engine/dependency sources,
  Kookoo corresponding sources, Zig runtime sources, explicit notices and
  manifests. All downloaded checksum entries verified independently.
- Core tests: 3336 passed, 16 skipped. Kookoo: 1109 tests, 6 skipped, no failures.
- Candidate app contains the explicit notices and passes signature verification.

The exact framework passed GUI/shell probing in
https://github.com/uuuyuqi/kookoo/actions/runs/43594876014 . Screenshot review
confirmed visible ANSI/CJK/emoji output. Eight brief IP-socket samples of the
app process observed no connections; this is not comprehensive traffic capture
or a statement about agent subprocesses or later updater activity.

The actual corresponding-source replacement route passed in
https://github.com/uuuyuqi/kookoo/actions/runs/43594815367 . A modified libintl
local-source dependency rebuilt successfully (207/207 steps); a linked program
executed its added function and returned 42. Kookoo then relinked against the
modified framework and passed ad-hoc code-sign verification without a maintainer
key. Modified test binaries were not published. This closes the previously
unverified technical relink step, not a blanket legal certification.

No engine release, production pin switch, main-branch change or appcast change
has occurred. Promotion still requires durable source/binary publication and
final distribution review. The untested human/hardware scenarios above remain.

## Promotion hold: baseline comparison found a build-flag difference

The original release archive was downloaded and matched its pinned SHA256.
Both archives have identical public headers/modulemap, the same 145 exported
`ghostty_*` symbols, arm64 architecture and macOS 13 minimum. They are NOT binary
identical: original archive has 226 members, while the earlier source-built
candidate has 277. The 51 additional objects are Sentry/Breakpad crash capture.
The original archive contains no Sentry transport objects. This makes the prior
candidate unsuitable as a minimal behavioral replacement, even though its
Sentry transport was local-only and tests passed.

The builder now explicitly sets `-Dsentry=false` for engine and core tests,
and the candidate workflow rejects crash-SDK archive members. The original
vendor's precise build command is not yet established solely by this comparison;
we are aligning observable binary dependency inventory, not claiming a complete
reproduction of their build environment. All previously recorded candidate hashes
remain historical evidence, NOT approved production pins. Rebuild, inventory,
license/source, GUI and relink evidence must be refreshed for the aligned binary.

The Sentry-disabled run 43595935107 passed. Binary comparison then matched all
226 archive members, 145 public engine symbols, headers and minimum platform.
Across all objects only the main Zig object's non-debug sections differed:
17 instruction bytes and two version strings. Its five affected functions are
version consumers (CLI, initialization log, VT reporting, ghostty_info, subprocess
environment). The source tarball lacks `.git`, so the default reports
`1.3.2-dev+0000000`; the original reports `1.3.2-HEAD-+88c3325`.
The builder now pins the original runtime version explicitly rather than claiming
an unknown commit. Sidecar provenance continues to identify the Kookoo build.
A further exact-section comparison is required before claiming this closes the
remaining metadata difference; archive/debug bytes are not expected to match.

## Aligned candidate verification (2026-11-14, not a production switch)

The final source build explicitly disables Sentry and pins the original runtime
version string. Run [43598330698](https://github.com/uuuyuqi/kookoo/actions/runs/43598330698)
passed core tests, 1109 Kookoo tests (6 skipped, zero failures), app packaging,
notice checks and ad-hoc signature verification. Its retained artifact is
14116316964. SHA256:

- Framework: `6bada6f5bf2e2105a1a5069dd705a1eafd6300a88fc19827e4b1fc53b0a58a10`
- Patched engine source: `ce3ccf361e0cb2bfd9b54ee657bb5a89c3e4b463c16a9b37b1c9ba823d7b2460`
- Candidate app source: `ff09ce897a708d90cae199a5c0053560b7703ddf4976b06a3cce22f8832ca7a8`

All materials passed their included SHA256SUMS. Independent inspection against
the pinned original framework found the same 226 archive members, 145 public
engine symbols, architecture, deployment target and headers. Every object's
non-DWARF section bytes, normalized relocations, and section-relative non-debug
symbol metadata matched. Archive and debug bytes do not match; this is stronger
runtime-code/data evidence, not a claim of a byte-identical archive or full
reconstruction of the vendor's unknown original build command.

The exact framework passed disposable-runner GUI probing in
[43601202057](https://github.com/uuuyuqi/kookoo/actions/runs/43601202057).
Screenshot inspection confirmed visible ANSI, CJK and emoji output. Real shell,
alternate screen, 5000-line output and OSC title worked. Eleven brief process-only
IP socket samples observed no connections, not a comprehensive network audit.
Human IME, interactive pane resize and physical GPU/sleep cases remain untested.

The exact corresponding-source bundles passed recipient relink verification in
[43601202060](https://github.com/uuuyuqi/kookoo/actions/runs/43601202060):
201/201 engine build steps succeeded, modified libintl's marker executed with
value 42, and Kookoo rebuilt/relinked with ad-hoc signature verification. This
uses the aligned no-Sentry/version flags. No private maintainer key was needed.
This is technical evidence for a usable replacement route, not legal advice.

The earlier Sentry-enabled candidates are superseded. Main, the production
engine pin, releases and appcast remain unchanged. Before adoption, rebase onto
the current app release and repeat integration tests; make source/notices durable
release assets, add notices to the product packaging and visible entry, and
include corresponding source for the actual shipping app (not this older
candidate snapshot). Follow engine-release-checklist.md.
