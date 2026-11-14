#!/usr/bin/env bash
# Disposable CI runner only. Never grants Accessibility or changes security policy.
set -euo pipefail
[[ "$(uname -s)" == Darwin && "${GITHUB_ACTIONS:-}" == true ]]
APP="$(cd "${1:?app bundle}" && pwd)"
OUT="$(pwd)/dist/ui-fixes-evidence"; mkdir -p "$OUT"
WORK=$(mktemp -d "${RUNNER_TEMP:-/tmp}/kookoo-ui.XXXXXX")
PID=''; trap '[[ -z "$PID" ]] || kill "$PID" 2>/dev/null || true; rm -rf "$WORK"' EXIT
export HOME="$WORK/home" CFFIXED_USER_HOME="$WORK/home" XDG_CONFIG_HOME="$WORK/home/.config"
mkdir -p "$HOME" "$XDG_CONFIG_HOME"
"$APP/Contents/MacOS/Kookoo" -AppleLanguages '(zh-Hans)' > "$OUT/app.log" 2>&1 & PID=$!
sleep 5
cat > "$WORK/ui.swift" <<'SWIFT'
import AppKit
import ApplicationServices
let pid = pid_t(CommandLine.arguments[1])!
let out = CommandLine.arguments[2]
let resources = URL(fileURLWithPath: CommandLine.arguments[3]).appendingPathComponent("Contents/Resources")
guard AXIsProcessTrusted() else { print("BLOCKED: Accessibility unavailable; not requesting permission"); exit(3) }
func value(_ e: AXUIElement, _ key: String) -> AnyObject? { var v: CFTypeRef?; return AXUIElementCopyAttributeValue(e,key as CFString,&v) == .success ? v : nil }
func children(_ e: AXUIElement) -> [AXUIElement] { value(e,kAXChildrenAttribute) as? [AXUIElement] ?? [] }
func labels(_ e: AXUIElement) -> [String] { [kAXTitleAttribute,kAXDescriptionAttribute,kAXValueAttribute].compactMap { value(e,$0) as? String } }
func find(_ e: AXUIElement, _ name: String, _ depth: Int = 0) -> AXUIElement? {
 if labels(e).contains(name) { return e }; if depth > 18 { return nil }
 for c in children(e) { if let f=find(c,name,depth+1) { return f } }; return nil
}
func dump(_ e: AXUIElement, _ d: Int = 0) { guard d < 18 else { return }; print(String(repeating:" ",count:d),value(e,kAXRoleAttribute) ?? "",labels(e)); for c in children(e) { dump(c,d+1) } }
func press(_ e: AXUIElement) {
 var target=e
 if value(e,kAXRoleAttribute) as? String == kAXStaticTextRole, let p=value(e,kAXParentAttribute) { target=p as! AXUIElement }
 if AXUIElementPerformAction(target,kAXPressAction as CFString) != .success {
  // SwiftUI List rows are selectable but do not expose AXPress. Click the
  // actual element center obtained from Accessibility, never guessed pixels.
  guard let pv=value(e,kAXPositionAttribute),let sv=value(e,kAXSizeAttribute) else {fatalError("Missing element geometry")}
  var point=CGPoint.zero;var size=CGSize.zero
  guard AXValueGetValue(pv as! AXValue,.cgPoint,&point),AXValueGetValue(sv as! AXValue,.cgSize,&size) else {fatalError("Invalid element geometry")}
  let center=CGPoint(x:point.x+size.width/2,y:point.y+size.height/2)
  CGEvent(mouseEventSource:nil,mouseType:.leftMouseDown,mouseCursorPosition:center,mouseButton:.left)!.post(tap:.cghidEventTap)
  CGEvent(mouseEventSource:nil,mouseType:.leftMouseUp,mouseCursorPosition:center,mouseButton:.left)!.post(tap:.cghidEventTap)
 }
 Thread.sleep(forTimeInterval:1)
}
func capture(_ name:String) { let p=Process();p.executableURL=URL(fileURLWithPath:"/usr/sbin/screencapture");p.arguments=["-x",out+"/"+name+".png"];try! p.run();p.waitUntilExit();guard p.terminationStatus==0 else {fatalError("screenshot failed")}}
let app=AXUIElementCreateApplication(pid)
NSRunningApplication(processIdentifier:pid)?.activate(options:[.activateIgnoringOtherApps])
Thread.sleep(forTimeInterval:1)
let menu=value(app,kAXMenuBarAttribute) as! AXUIElement
guard let cycle=find(menu,"循环切换侧边栏"), (value(cycle,kAXMenuItemCmdCharAttribute) as? String)?.lowercased() == "b" else { dump(app);fatalError("Missing Command+B cycle menu") }
capture("sidebar-full")
for name in ["sidebar-compact","sidebar-hidden","sidebar-restored"] {
 let down=CGEvent(keyboardEventSource:nil,virtualKey:11,keyDown:true)!;down.flags = .maskCommand
 let up=CGEvent(keyboardEventSource:nil,virtualKey:11,keyDown:false)!;up.flags = .maskCommand
 down.postToPid(pid);up.postToPid(pid);Thread.sleep(forTimeInterval:1)
 capture(name)
}
guard let settings=find(menu,"设置…") ?? find(menu,"Settings…") else { dump(menu);fatalError("Missing settings") }
press(settings)
guard let appearance=find(app,"外观") else { dump(app);fatalError("Missing appearance") }
press(appearance)
dump(app)
guard find(app,"应用图标") != nil, find(app,"珍珠") != nil,find(app,"棉花糖") != nil else { fatalError("Chinese icon names missing") }
guard find(app,"App Icon") == nil, find(app,"Pearl") == nil else {fatalError("English icon labels leaked")}
capture("chinese-icons")
guard let pearl=find(app,"珍珠图标") ?? find(app,"珍珠") else {fatalError("Missing pearl")}
press(pearl)
guard find(app,"更改应用图标？") == nil else { fatalError("Unexpected confirmation dialog") }
func iconBytes(_ name:String) -> Data { try! Data(contentsOf:resources.appendingPathComponent(name)) }
guard iconBytes("AppIcon.icns") == iconBytes("IconChoices/01-pearl.icns") else {fatalError("Direct selection did not apply pearl")}
capture("chinese-pearl-selected")
press(find(app,"珍珠图标") ?? find(app,"珍珠")!)
guard iconBytes("AppIcon.icns") == iconBytes("IconChoices/01-pearl.icns") else {fatalError("Repeat selection failed")}
guard let original=find(app,"Kookoo图标") else {dump(app);fatalError("Missing original icon")}
press(original)
guard iconBytes("AppIcon.icns") == iconBytes("IconChoices/default.icns") else {fatalError("Default restoration failed")}
print("PASS: Chinese icon settings, immediate selection, repeat selection and current-default restoration verified; Command+B sent three times with screenshots for visual state verification.")
SWIFT
set +e
swift "$WORK/ui.swift" "$PID" "$OUT" "$APP" > "$OUT/RESULT.txt" 2>&1
rc=$?
set -e
cat "$OUT/RESULT.txt"
[[ "$rc" == 0 ]] && codesign --verify --deep --strict "$APP"
exit "$rc"
