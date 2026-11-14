# Engine publication and promotion checklist

This is a proposed process, not a release action. Engine work remains isolated
from `main`, the application feed, and the installed application's engine pin.

## Separate the three decisions

1. **Source candidate:** pinned Ghostty fork + existing issue53 patch, reviewed
   toolchain, explicit license/source materials and automated verification.
2. **Durable engine release:** publish only after its source/relink evidence is
   reviewed, using a distinct non-SemVer tag such as
   `engine-88c3325-kooky53-kookoo1`, marked prerelease and `make_latest=false`.
   Never add an engine-only artifact to `appcast.xml`.
3. **Application adoption:** a separate normal app commit updates the engine
   archive hash and notices hash, packages notices before signing, and runs app,
   GUI, DMG and updater regression checks. A future app can stay on the current
   engine until these gates pass.

The fallback `ReleaseVersion` parser accepts only numeric three-part SemVer, so
an `engine-...` tag is not an application version. Still explicitly suppress
GitHub's Latest designation and keep the application feed untouched.

## Durable assets under uuuyuqi/kookoo

- Exact `GhosttyKit.xcframework.tar.gz` tested by the candidate run.
- Small notice bundle for inclusion in the application.
- Full corresponding-source/relink bundle from the same candidate, not merely
  links to somebody else's repository or an expiring Actions artifact.
- `SHA256SUMS`, source/toolchain provenance, explicit component/notice manifest,
  test and recipient-side modified-libintl relink evidence.

A published engine should never silently replace bytes under an existing tag.
Create a new engine identity on changes. Do not add fallback download URLs or
ignore a checksum failure. Retain the previous engine identity for rollback.
No private Sparkle signing key is needed to build/relink an engine; app update
signing remains in its existing trusted release flow.

## Application-source correspondence and licenses

The candidate bundle's Kookoo source snapshot matches the candidate's app, not
all future releases. When a later application version adopts the engine,
provide that actual application version's corresponding source/relink materials
alongside it. Retain the exact engine source and dependencies for the lifetime
required by the selected LGPL compliance route. Recipients must be able to
replace libintl and relink without any maintainer's private key.

This is technical packaging guidance, not legal certification. Review the
final distribution and terms, including reverse-engineering/modification rights,
FTL attribution, OFL font terms and any changed dependencies before adoption.

## Still outside automated probe coverage

- Human IME composition and keyboard/input-source transitions.
- Repeated pane resize/drag, GPU/device-specific rendering and sleep/wake.
- Sustained crash/memory-pressure behavior and old configuration edge cases.

Existing Ghostty-default configuration compatibility is deliberately unchanged.
Do not use engine adoption as an implicit configuration migration.
