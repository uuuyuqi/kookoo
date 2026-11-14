# In-app updates

Kookoo integrates Sparkle 2.10.1, but in-app installation is **disabled until a
release-signing public key is configured**. The current preview still uses
manual browser downloads. That fallback includes GitHub prereleases and excludes
drafts; stable builds exclude previews. It inspects the newest 100 published
GitHub release records.

A first build containing the configured updater must be installed manually.
Older 0.1.x builds cannot acquire a new updater without that initial install.

## Maintainer setup (not performed automatically)

1. Establish approved safe storage for an Ed25519 release-signing private key.
   Generate it using Sparkle's official tooling. Do not commit or log it, place
   it in a build artifact, or use a temporary CI fixture key for production.
2. Embed only its base64 public key using `KOOKOO_UPDATE_PUBLIC_KEY` when building.
3. Host a signed-update appcast at
   `https://raw.githubusercontent.com/uuuyuqi/kookoo/main/appcast.xml`.
   Preview items must use `<sparkle:channel>preview</sparkle:channel>`.
4. Use Sparkle's `generate_appcast`/`sign_update` with the protected private key
   to sign the exact released update archive. Attach `sparkle:edSignature`,
   length, macOS minimum and monotonically increasing bundle versions.
5. Test upgrade on an isolated Mac: valid archive, tampered archive, wrong key,
   cancel/retry, interrupted network, readonly/disk-image launch, and an active
   terminal session. Never disable Gatekeeper or endpoint policy to pass tests.

The updater checks/downloads only when the user asks. It does not send a system
profile. Sparkle's normal update UI is used; immediately before restart Kookoo
warns that terminal commands and agents will stop. Later postpones restart and
Check for Updates can resume it. Normal application shutdown still terminates
terminal processes; it is not live process migration.

Ed25519 authenticity is separate from Apple Developer ID/notarization. An ad-hoc
build is not notarized and can still be blocked by Gatekeeper or enterprise
policy. This integration does not remove quarantine or disable safety controls.
Do not describe a release as auto-updatable until the signed feed and a complete
old-to-new installation have actually been verified.

References: https://sparkle-project.org/documentation/ and
https://sparkle-project.org/documentation/publishing/.

## Current production trust and recovery limit

The approved private key is stored only in this repository's encrypted GitHub
Actions secret `KOOKOO_SPARKLE_PRIVATE_KEY`; public key is in
`config/sparkle-public-key.txt`. There is no independent backup, and GitHub does
not provide secret-value readback. Do not delete or replace the secret casually.
No additional private-key store or export is authorized by this setup.

If this key becomes unavailable, these ad-hoc-signed builds have no Developer ID
identity to rely on for seamless key rotation. Existing installs may require a
manual, explicitly verified reinstall to acquire a new update trust anchor.
Plan a separately approved encrypted backup/recovery process before broad
production distribution. Never recover by disabling archive verification.
