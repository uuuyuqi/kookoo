# Independent Kookoo terminal engine: 88c3325 + issue53 (kookoo1)

This is an **engine-only prerelease**, not a new Kookoo application release. It
must not become GitHub Latest, enter `appcast.xml`, or change the installed app.
It does not imply endorsement by Ghostty or the original Kooky maintainers.

## Fixed inputs and evidence

- Ghostty fork source: `manaflow-ai/ghostty@88c3325dc9698d887da7e07ee0f9b79c53020be2`.
- Existing Kooky issue53 patch SHA256:
  `cd81f71d04b05f26abf38127e716f221324316ea6026e0c6823186a20fc94f39`.
- Framework SHA256:
  `6bada6f5bf2e2105a1a5069dd705a1eafd6300a88fc19827e4b1fc53b0a58a10`.
- Final engine [run 43598330698](https://github.com/uuuyuqi/kookoo/actions/runs/43598330698),
  source-builder commit `062cf96269218f0c6c39fb809305f81073c6e2e7`.
- Application integration and modified-libintl recipient relink:
  [run 43606097707](https://github.com/uuuyuqi/kookoo/actions/runs/43606097707),
  app commit `5d2a7159f7e49a77761ba1369cd986ecae9ac7a0`.

Sentry is explicitly disabled, and the runtime version string is fixed to
`1.3.2-HEAD-+88c3325`. Source rebuilding and API/inventory checks are not a claim
of byte-for-byte identity with the original Kooky release binary.

## Assets and layout

- `GhosttyKit.xcframework.tar.gz`: exact tested engine framework.
- `EngineNotices.tar.gz`: top-level `EngineNotices/` containing `licenses/`,
  `license-manifest.json`, `ENGINE-NOTICE.md`, `README.md` and `SHA256SUMS`.
  Verify this bundle before copying notices into the app and code-signing it.
- `EngineCorrespondingSource.tar.gz`: current adoption app's complete source
  materials at archive root (`sources/`, notices, `MATERIALS.json`, checksums and
  rebuild/relink instructions). Includes the exact pinned engine/dependency and
  runtime sources, and the **app snapshot at 5d2a715**, not a future app version.
- `EngineRelinkEvidence.tar.gz`: modified-libintl relink evidence from the same
  successful application-integration run, with its source-run record.
- `PROVENANCE.txt`, `APPLICATION-MATERIALS.json`, `APPLICATION-SHA256SUMS`,
  `RELEASE-NOTES.md` and `SHA256SUMS`: input and asset verification records.

Ghostty is MIT licensed, but not every dependency is MIT. The materials preserve
static libintl LGPL 2.1 notices and the source/relink route, FreeType's selected
FTL terms, font terms and other component licenses. Recipients may modify the
library and rebuild/relink without a maintainer's private signing key. This is
technical provenance and packaging evidence, **not a legal compliance guarantee**.

A later application adopting this engine must refresh its corresponding app
source, include accessible notices before signing, and pass its own packaging,
GUI and updater checks. This engine publication does not substitute for them.
Human IME transitions, device-specific rendering and long-duration behavior are
not claimed fully covered by CI probes.

## Publication safety and recovery

The non-SemVer prerelease tag `engine-88c3325-kooky53-kookoo1` targets the exact
adoption app commit above, even if the publication workflow runs on a newer
isolated-branch commit. It is created once, without force; an existing tag or
release makes the workflow fail rather than replace bytes. Every published asset
is downloaded again and compared to the prepared asset hash.

If publication fails after tag creation or partial upload, inspect the durable
state and report it. Do not delete/recreate the tag or rerun with overwrite flags.
A replacement engine requires a new identity. Neither main, Pages, appcast nor
the production engine pin is changed by this workflow.
