#!/usr/bin/env bash
# Only trusted main-branch CI receives the private key. Never trace secret input.
set +x
set -euo pipefail
: "${KOOKOO_SPARKLE_PRIVATE_KEY:?Missing protected update signing key}"
VERSION="$(plutil -extract CFBundleShortVersionString raw dist/Kookoo.app/Contents/Info.plist)"
DMG="dist/Kookoo-v${VERSION}.dmg"
PUBLIC_KEY="$(cat config/sparkle-public-key.txt)"
test "$(plutil -extract SUPublicEDKey raw dist/Kookoo.app/Contents/Info.plist)" = "$PUBLIC_KEY"
TOOLS="${RUNNER_TEMP:-/tmp}/kookoo-sparkle-2.10.1"
mkdir -p "$TOOLS"
curl --fail --location --silent --show-error https://github.com/sparkle-project/Sparkle/releases/download/2.10.1/Sparkle-2.10.1.tar.xz -o "$TOOLS/release.tar.xz"
printf '%s  %s\n' '1a856d2a9edb8e628de88121d7be04cf0e2167f8641650b78fca00b14244cf27' "$TOOLS/release.tar.xz" | shasum -a 256 -c -
tar -xf "$TOOLS/release.tar.xz" -C "$TOOLS"
SIGNATURE="$(printf '%s' "$KOOKOO_SPARKLE_PRIVATE_KEY" | "$TOOLS/bin/sign_update" --ed-key-file - -p "$DMG")"
unset KOOKOO_SPARKLE_PRIVATE_KEY
export VERSION DMG PUBLIC_KEY SIGNATURE
swift scripts/verify-update-signature.swift "$DMG" "$PUBLIC_KEY" "$SIGNATURE"
python3 - <<'PY'
import os,xml.etree.ElementTree as ET,email.utils
ns='http://www.andymatuschak.org/xml-namespaces/sparkle'
ET.register_namespace('sparkle',ns)
rss=ET.Element('rss',version='2.0');ch=ET.SubElement(rss,'channel')
ET.SubElement(ch,'title').text='Kookoo Preview Updates'
ET.SubElement(ch,'link').text='https://github.com/uuuyuqi/kookoo/releases'
it=ET.SubElement(ch,'item');v=os.environ['VERSION']
ET.SubElement(it,'title').text='Kookoo '+v+' Preview'
ET.SubElement(it,'pubDate').text=email.utils.formatdate(usegmt=True)
ET.SubElement(it,'description').text='Kookoo preview. Restart closes terminal sessions. Ad-hoc signed; Apple notarization and enterprise security restrictions still apply.'
for k,value in [('version',v),('shortVersionString',v),('channel','preview'),('minimumSystemVersion','14.0.0'),('hardwareRequirements','arm64')]:
 ET.SubElement(it,'{'+ns+'}'+k).text=value
ET.SubElement(it,'enclosure',{'url':f'https://github.com/uuuyuqi/kookoo/releases/download/v{v}/Kookoo-v{v}.dmg','length':str(os.path.getsize(os.environ['DMG'])),'type':'application/octet-stream','{'+ns+'}edSignature':os.environ['SIGNATURE']})
ET.ElementTree(rss).write('dist/appcast.xml',encoding='utf-8',xml_declaration=True)
PY
shasum -a 256 "$DMG" dist/appcast.xml > dist/SHA256SUMS
echo 'Signed archive verified; wrong-key and tampered-byte checks rejected as expected.'
