# In-app updates

Kookoo 0.1.3 Preview enables Sparkle 2.10.1 using the embedded public key in
`config/sparkle-public-key.txt` and the fixed HTTPS appcast. Trusted main builds
sign their update archives through the protected Actions secret; private keys
are never part of the app or release artifacts. Builds without a configured
key fail closed and retain the manual-download fallback.

Versions 0.1.0–0.1.2 need one manual installation of 0.1.3 to obtain the trust
anchor. Thereafter use Help → Check for Updates; installation/restart requires
user confirmation. Automatic checks and downloads remain off.

Verified: public release asset byte equality and Ed25519 verification; actual
Sparkle CLI installation from the production HTTPS feed into an isolated older
full-App fixture; bad-signature rejection; download interruption; read-only
volume rejection. GUI Later/Restart interaction, running terminal UX and the
user's Gatekeeper/enterprise admission policies are not covered by those tests.

## Maintainer release procedure

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
