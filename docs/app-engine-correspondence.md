# Refresh source materials for each adopting app version

The reviewed engine candidate has a fixed framework SHA256
`6bada6f5bf2e2105a1a5069dd705a1eafd6300a88fc19827e4b1fc53b0a58a10`.
Its old app-source snapshot must not be presented as the source for a later app.

Run after all app changes are committed, on a clean tracked tree:

```sh
python3 scripts/package-app-engine-materials.py \
  /path/to/reviewed-engine/EngineCompliance dist/app-engine-materials
```

The input directory's parent must contain the reviewed
`GhosttyKit.xcframework.tar.gz` and `PROVENANCE.txt`. The helper pins and verifies
both, pins the original compliance checksum manifest, validates every listed
file, and refuses unexpected files, symlinks, dirty tracked sources or output
replacement. It does not rebuild the engine, change the app's pin, or publish.

`dist/app-engine-materials` contains the unchanged engine
source/runtime/license materials and a new `git archive HEAD` of the current
app. `MATERIALS.json` records the current version, exact commit and input hashes.
The old candidate app archive is replaced, while original engine README/checksums
are retained explicitly as historical records. A new top-level README gives the
current static-libintl replacement/relink route and preserves recipient rights.

Integration responsibilities remain separate:

- Put the required notices and LGPL notification in app resources with a visible
  entry point before code-signing; do not stuff large source archives into the app.
- Keep source materials alongside the exact released binary at a durable URL.
- Run current-app build, tests, modified-library relink and GUI/update checks;
  source packaging alone is not those checks or a legal compliance guarantee.
- Regenerate materials after any version/commit change. Do not edit a reviewed
  engine's source archive or replace bytes under an existing engine identity.
