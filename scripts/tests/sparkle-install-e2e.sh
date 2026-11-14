#!/bin/bash
# Real Sparkle installer smoke test on an isolated macOS CI runner.
# No production secrets, global /Applications, quarantine edits or sudo.
# Usage: scripts/tests/sparkle-install-e2e.sh dist/Kookoo.app
set -euo pipefail
[[ "$(uname -s)" == Darwin && "${CI:-}" == true ]] || { echo 'macOS CI only'; exit 1; }
umask 077
# This test deliberately cannot consume release signing secrets.
unset KOOKOO_SPARKLE_PRIVATE_KEY SPARKLE_PRIVATE_KEY || true
APP_INPUT="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
[[ -f "$APP_INPUT/Contents/Info.plist" ]] || { echo 'Built App required'; exit 1; }
WORK="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/kookoo-updater-e2e.XXXXXX")"
LOGS="${KOOKOO_E2E_LOGS:-$PWD/dist/updater-e2e-logs}"
mkdir -p "$LOGS"
SERVER_PID=''; MOUNT=''
cleanup() {
  [[ -z "$SERVER_PID" ]] || kill "$SERVER_PID" 2>/dev/null || true
  [[ -z "$MOUNT" ]] || hdiutil detach "$MOUNT" -quiet 2>/dev/null || true
  rm -rf "$WORK"
}
trap cleanup EXIT

# Sparkle removed the CLI from binary distributions in 2.9. Build its official
# CLI, not a home-made copy/replace installer. Pin both release and commit.
git clone --quiet --depth 1 --branch 2.10.1 https://github.com/sparkle-project/Sparkle.git "$WORK/Sparkle"
[[ "$(git -C "$WORK/Sparkle" rev-parse HEAD)" == ab7d71291238df6e0492143b120c9b696a35f603 ]]
xcodebuild -project "$WORK/Sparkle/Sparkle.xcodeproj" -scheme sparkle-cli \
  -configuration Release -derivedDataPath "$WORK/derived" \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual ONLY_ACTIVE_ARCH=YES \
  build >"$LOGS/cli-build.log" 2>&1
CLI_APP="$WORK/derived/Build/Products/Release/sparkle.app"
CLI="$CLI_APP/Contents/MacOS/sparkle"
[[ -x "$CLI" ]]
codesign --verify --deep --strict "$CLI_APP"

# Fresh fixture-only key stays in the private temporary directory and is deleted
# by trap. No keychain, production secret env var or public artifact is involved.
cat > "$WORK/sign.swift" <<'SWIFT'
import CryptoKit
import Foundation
let args = CommandLine.arguments
if args[1] == "generate" {
    let key = Curve25519.Signing.PrivateKey()
    try key.rawRepresentation.write(to: URL(fileURLWithPath: args[2]))
    try Data(key.publicKey.rawRepresentation.base64EncodedString().utf8).write(to: URL(fileURLWithPath: args[3]))
} else {
    let key = try Curve25519.Signing.PrivateKey(rawRepresentation: Data(contentsOf: URL(fileURLWithPath: args[2])))
    let bytes = try Data(contentsOf: URL(fileURLWithPath: args[3]))
    let signature = try key.signature(for: bytes)
    try Data(signature.base64EncodedString().utf8).write(to: URL(fileURLWithPath: args[4]))
}
SWIFT
xcrun swift "$WORK/sign.swift" generate "$WORK/fixture-key" "$WORK/fixture-pub"
mkdir -p "$WORK/http" "$WORK/new"
# Only initial fixture setup uses ditto. The tested replacement below is solely
# performed by Sparkle's authenticated installer.
ditto "$APP_INPUT" "$WORK/new/Kookoo.app"
python3 - "$WORK" <<'PY'
import pathlib, plistlib, sys, uuid
p=pathlib.Path(sys.argv[1]); ident='com.uuuyuqi.kookoo.updater-e2e.'+uuid.uuid4().hex
(p/'bundle-id').write_text(ident)
info=p/'new/Kookoo.app/Contents/Info.plist'
d=plistlib.loads(info.read_bytes())
d.update(CFBundleIdentifier=ident,CFBundleVersion='9000.0.2',CFBundleShortVersionString='9000.0.2',
         SUPublicEDKey=(p/'fixture-pub').read_text(),SUVerifyUpdateBeforeExtraction=True,
         SUEnableAutomaticChecks=False,SUAutomaticallyUpdate=False,SUSendProfileInfo=False)
# The external CLI supplies the loopback feed; do not use production feed/key.
d.pop('SUFeedURL',None); d.pop('SURequireSignedFeed',None)
info.write_bytes(plistlib.dumps(d)); (p/'new/Kookoo.app/Contents/Resources/E2E-new-marker').write_text('NEW')
PY
codesign --force --sign - "$WORK/new/Kookoo.app"
codesign --verify --deep --strict "$WORK/new/Kookoo.app"
ditto -c -k --sequesterRsrc --keepParent "$WORK/new/Kookoo.app" "$WORK/http/update.zip"
xcrun swift "$WORK/sign.swift" sign "$WORK/fixture-key" "$WORK/http/update.zip" "$WORK/signature"

# Loopback-only fixture server. Delay endpoint supports cancellation before any
# update archive is downloaded. It is not a claim about the production GUI.
cat > "$WORK/server.py" <<'PY'
import http.server,pathlib,sys,time
root,port_file=sys.argv[1:]
class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self,*a,**kw):super().__init__(*a,directory=root,**kw)
    def do_GET(self):
        if self.path.startswith('/slow.xml'):
            pathlib.Path(root,'slow-requested').write_text('yes');time.sleep(40)
            self.path='/good.xml'
        super().do_GET()
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),Handler)
pathlib.Path(port_file).write_text(str(server.server_port));server.serve_forever()
PY
python3 "$WORK/server.py" "$WORK/http" "$WORK/port" >"$LOGS/http.log" 2>&1 & SERVER_PID=$!
for i in {1..50}; do [[ -f "$WORK/port" ]] && break; sleep .1; done
PORT="$(cat "$WORK/port")"
python3 - "$WORK" "$PORT" <<'PY'
import base64,pathlib,sys,xml.etree.ElementTree as E
p=pathlib.Path(sys.argv[1]);port=sys.argv[2];ns='http://www.andymatuschak.org/xml-namespaces/sparkle'
E.register_namespace('sparkle',ns)
for name,signature in [('good',(p/'signature').read_text()),('bad',base64.b64encode(bytes(64)).decode())]:
 r=E.Element('rss',version='2.0');c=E.SubElement(r,'channel');i=E.SubElement(c,'item')
 E.SubElement(i,'title').text='Kookoo E2E';E.SubElement(i,'{'+ns+'}version').text='9000.0.2'
 E.SubElement(i,'{'+ns+'}minimumSystemVersion').text='14.0'
 E.SubElement(i,'enclosure',{'url':f'http://127.0.0.1:{port}/update.zip','length':str((p/'http/update.zip').stat().st_size),'type':'application/octet-stream','{'+ns+'}edSignature':signature})
 E.ElementTree(r).write(p/'http'/f'{name}.xml',encoding='utf-8',xml_declaration=True)
PY

make_old() {
  mkdir -p "$1"
  ditto "$WORK/new/Kookoo.app" "$1/Kookoo.app"
  python3 - "$1/Kookoo.app" <<'PY'
import pathlib,plistlib,sys
p=pathlib.Path(sys.argv[1]);f=p/'Contents/Info.plist';d=plistlib.loads(f.read_bytes())
d.update(CFBundleVersion='9000.0.1',CFBundleShortVersionString='9000.0.1');f.write_bytes(plistlib.dumps(d))
(p/'Contents/Resources/E2E-new-marker').unlink()
PY
  codesign --force --sign - "$1/Kookoo.app"
}
version() { /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$1/Contents/Info.plist"; }
run_cli() {
  # An outer timeout makes a stuck install an explicit failure, not an endless CI.
  python3 - "$LOGS/$1.log" "$CLI" "$2" "$3" <<'PY'
import subprocess,sys
log,cli,app,feed=sys.argv[1:]
with open(log,'w') as f:
 try:
  p=subprocess.run([cli,app,'--check-immediately','--grant-automatic-checks','--feed-url',feed,'--user-agent-name','Kookoo-Isolated-CI','--verbose'],stdout=f,stderr=subprocess.STDOUT,timeout=180)
  raise SystemExit(p.returncode)
 except subprocess.TimeoutExpired:
  f.write('\nE2E TIMEOUT\n');raise SystemExit(124)
PY
}

make_old "$WORK/installed"
run_cli valid "$WORK/installed/Kookoo.app" "http://127.0.0.1:$PORT/good.xml"
[[ "$(version "$WORK/installed/Kookoo.app")" == 9000.0.2 ]]
[[ "$(cat "$WORK/installed/Kookoo.app/Contents/Resources/E2E-new-marker")" == NEW ]]
codesign --verify --deep --strict "$WORK/installed/Kookoo.app"
cmp "$WORK/installed/Kookoo.app/Contents/MacOS/Kookoo" "$WORK/new/Kookoo.app/Contents/MacOS/Kookoo"
echo 'PASS: real Sparkle installer upgraded isolated full App fixture' | tee "$LOGS/results.txt"

make_old "$WORK/bad"
set +e; run_cli bad-signature "$WORK/bad/Kookoo.app" "http://127.0.0.1:$PORT/bad.xml"; BAD=$?; set -e
[[ "$BAD" != 0 && "$BAD" != 124 ]]
[[ "$(version "$WORK/bad/Kookoo.app")" == 9000.0.1 ]]
[[ ! -e "$WORK/bad/Kookoo.app/Contents/Resources/E2E-new-marker" ]]
# Require rejection evidence, not merely an unrelated network failure.
grep -Eiq 'signature|EdDSA|validation|validated' "$LOGS/bad-signature.log"
echo 'PASS: bad signature rejected; old App unchanged' | tee -a "$LOGS/results.txt"

make_old "$WORK/cancel"
python3 - "$CLI" "$WORK/cancel/Kookoo.app" "$PORT" "$WORK/http/slow-requested" "$LOGS/cancel.log" <<'PY'
import pathlib,subprocess,sys,time
cli,app,port,marker,log=sys.argv[1:]
with open(log,'w') as f:
 p=subprocess.Popen([cli,app,'--check-immediately','--grant-automatic-checks','--feed-url',f'http://127.0.0.1:{port}/slow.xml','--user-agent-name','Kookoo-Isolated-CI','--verbose'],stdout=f,stderr=subprocess.STDOUT)
 try:
  for _ in range(200):
   if pathlib.Path(marker).exists():break
   if p.poll() is not None:raise RuntimeError('CLI exited before delayed request')
   time.sleep(.1)
  else:raise RuntimeError('No delayed request')
 finally:
  p.terminate()
  try:p.wait(timeout=10)
  except subprocess.TimeoutExpired:p.kill();p.wait()
PY
[[ "$(version "$WORK/cancel/Kookoo.app")" == 9000.0.1 ]]
[[ ! -e "$WORK/cancel/Kookoo.app/Contents/Resources/E2E-new-marker" ]]
echo 'PASS: interrupted feed request left old App unchanged (not GUI cancellation)' | tee -a "$LOGS/results.txt"

make_old "$WORK/readonly-source"
hdiutil create -quiet -srcfolder "$WORK/readonly-source" -volname Kookoo-E2E-Readonly -format UDRO "$WORK/readonly.dmg"
MOUNT="$WORK/readonly-mount";mkdir -p "$MOUNT"
hdiutil attach -quiet -readonly -nobrowse -mountpoint "$MOUNT" "$WORK/readonly.dmg"
set +e; run_cli readonly "$MOUNT/Kookoo.app" "http://127.0.0.1:$PORT/good.xml"; READONLY=$?; set -e
[[ "$READONLY" != 0 && "$READONLY" != 124 ]]
[[ "$(version "$MOUNT/Kookoo.app")" == 9000.0.1 ]]
echo 'PASS: read-only volume not replaced without interaction' | tee -a "$LOGS/results.txt"
echo 'NOT COVERED: production key/feed, GUI Later/Restart, running terminals, Gatekeeper admission, enterprise policy' | tee -a "$LOGS/results.txt"
