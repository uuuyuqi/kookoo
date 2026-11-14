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
func labels(_ e: AXUIElement) -> [String] {
    [kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute].compactMap { value(e, $0) as? String }
}
func dump(_ e: AXUIElement, _ depth: Int = 0) {
    guard depth < 12 else { return }
    print(String(repeating: " ", count: depth), value(e, kAXRoleAttribute) ?? "", labels(e))
    for child in children(e) { dump(child, depth + 1) }
}
func children(_ e: AXUIElement) -> [AXUIElement] { value(e, kAXChildrenAttribute) as? [AXUIElement] ?? [] }
func find(_ e: AXUIElement, _ name: String, _ depth: Int = 0) -> AXUIElement? {
    if labels(e).contains(name) { return e }
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
dump(app)
guard var link = find(app, "Third-party licenses") else { print("FAIL: Missing licenses AX element"); exit(1) }
if value(link, kAXRoleAttribute) as? String != kAXButtonRole,
   let parent = value(link, kAXParentAttribute) { link = parent as! AXUIElement }
guard AXUIElementPerformAction(link, kAXPressAction as CFString) == .success else { print("FAIL: License button action failed"); exit(1) }
Thread.sleep(forTimeInterval: 2)
let windows = value(app, kAXWindowsAttribute) as? [AXUIElement] ?? []
guard let licenseWindow = windows.first(where: { title($0) == "Third-party licenses" }),
      find(licenseWindow, "Open full license texts") != nil else {
    print("FAIL: Internal license window did not open"); exit(1)
}
dump(licenseWindow)
print("PASS: actual About opened, licenses button pressed, internal read-only license window and full-text folder entry verified.")
SWIFT
set +e
swift "$WORK/about.swift" "$PID" > "$OUT/RESULT.txt" 2>&1
rc=$?
set -e
/usr/sbin/screencapture -x "$OUT/screen.png" 2> "$OUT/screenshot-error.txt" || true
cat "$OUT/RESULT.txt"
if [[ "$rc" == 3 ]]; then exit 3; fi
exit "$rc"
