#!/usr/bin/env bash
# Disposable runner only; no permission grants or security changes.
set -euo pipefail
[[ "$(uname -s)" == Darwin && "${GITHUB_ACTIONS:-}" == true ]]
APP="$(cd "${1:?app bundle required}" && pwd)"
OUT="$(pwd)/dist/engine-about-evidence"
mkdir -p "$OUT"
WORK=$(mktemp -d "${RUNNER_TEMP:-/tmp}/kookoo-about.XXXXXX")
PID=''
trap '[[ -z "$PID" ]] || kill "$PID" 2>/dev/null || true; rm -rf "$WORK"' EXIT
export HOME="$WORK/home" CFFIXED_USER_HOME="$WORK/home" XDG_CONFIG_HOME="$WORK/home/.config"
mkdir -p "$HOME" "$XDG_CONFIG_HOME"
"$APP/Contents/MacOS/Kookoo" > "$OUT/app.log" 2>&1 & PID=$!
sleep 5
cat > "$WORK/about.swift" <<'SWIFT'
import AppKit
import ApplicationServices
let pid = pid_t(CommandLine.arguments[1])!
guard AXIsProcessTrusted() else {
    print("BLOCKED: runner Accessibility not granted; no prompt or permission change attempted.")
    exit(3)
}
func value(_ e: AXUIElement, _ key: String) -> AnyObject? {
    var v: CFTypeRef?
    return AXUIElementCopyAttributeValue(e, key as CFString, &v) == .success ? v : nil
}
func title(_ e: AXUIElement) -> String { value(e, kAXTitleAttribute) as? String ?? "" }
func children(_ e: AXUIElement) -> [AXUIElement] { value(e, kAXChildrenAttribute) as? [AXUIElement] ?? [] }
func find(_ e: AXUIElement, _ name: String, _ depth: Int = 0) -> AXUIElement? {
    if title(e) == name { return e }
    if depth > 12 { return nil }
    for c in children(e) { if let found = find(c, name, depth + 1) { return found } }
    return nil
}
let app = AXUIElementCreateApplication(pid)
guard let bar = value(app, kAXMenuBarAttribute) else { fatalError("Missing app menu bar") }
let menu = bar as! AXUIElement
guard let item = find(menu, "About Kookoo") else { fatalError("Missing About Kookoo menu item") }
guard AXUIElementPerformAction(item, kAXPressAction as CFString) == .success else { fatalError("About action failed") }
Thread.sleep(forTimeInterval: 2)
guard let link = find(app, "Third-party licenses ↗") else { fatalError("Missing visible third-party licenses button") }
guard AXUIElementPerformAction(link, kAXPressAction as CFString) == .success else { fatalError("License button action failed") }
print("PASS: actual About menu opened; visible Third-party licenses button found and pressed through Accessibility.")
SWIFT
set +e
swift "$WORK/about.swift" "$PID" > "$OUT/RESULT.txt" 2>&1
rc=$?
set -e
/usr/sbin/screencapture -x "$OUT/screen.png" 2> "$OUT/screenshot-error.txt" || true
cat "$OUT/RESULT.txt"
if [[ "$rc" == 3 ]]; then exit 3; fi
exit "$rc"
