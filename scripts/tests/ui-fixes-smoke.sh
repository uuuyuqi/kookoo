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
// Seed a known workspace name through the existing keyboard entry point,
// then exercise real double clicks on its AX-derived title geometry.
func key(_ code: CGKeyCode, flags: CGEventFlags = []) {
 for down in [true, false] {
  let e=CGEvent(keyboardEventSource:nil,virtualKey:code,keyDown:down)!
  e.flags=flags; e.postToPid(pid)
 }
 Thread.sleep(forTimeInterval:0.35)
}
func editor(_ e: AXUIElement) -> AXUIElement? {
 if value(e,kAXRoleAttribute) as? String == kAXTextFieldRole { return e }
 for c in children(e) { if let f=editor(c) { return f } }
 return nil
}
func replaceDraft(_ text:String) {
 guard editor(app) != nil else {dump(app);fatalError("Missing workspace rename field")}
 key(0,flags:.maskCommand)
 let chars=Array(text.utf16)
 for down in [true,false] {
  let e=CGEvent(keyboardEventSource:nil,virtualKey:0,keyDown:down)!
  e.keyboardSetUnicodeString(stringLength:chars.count,unicodeString:chars)
  e.postToPid(pid)
 }
 Thread.sleep(forTimeInterval:0.35)
}
func doubleClickTitle(_ name:String) {
 guard let e=find(app,name),let pv=value(e,kAXPositionAttribute),let sv=value(e,kAXSizeAttribute) else {dump(app);fatalError("Missing title geometry: "+name)}
 var point=CGPoint.zero;var size=CGSize.zero
 guard AXValueGetValue(pv as! AXValue,.cgPoint,&point),AXValueGetValue(sv as! AXValue,.cgSize,&size) else {fatalError("Invalid title geometry")}
 let center=CGPoint(x:point.x+size.width/2,y:point.y+size.height/2)
 for count in 1...2 {
  for type in [CGEventType.leftMouseDown,.leftMouseUp] {
   let e=CGEvent(mouseEventSource:nil,mouseType:type,mouseCursorPosition:center,mouseButton:.left)!
   e.setIntegerValueField(.mouseEventClickState,value:Int64(count));e.post(tap:.cghidEventTap)
  }
  Thread.sleep(forTimeInterval:0.08)
 }
 Thread.sleep(forTimeInterval:0.6)
 guard editor(app) != nil else {dump(app);fatalError("Double-click did not start inline rename")}
}
key(15,flags:[.maskCommand,.maskShift])
replaceDraft("Kookoo rename target")
key(36)
guard find(app,"Kookoo rename target") != nil,editor(app) == nil else {dump(app);fatalError("Seed rename failed")}
doubleClickTitle("Kookoo rename target")
replaceDraft("双击修改标题")
key(36)
guard find(app,"双击修改标题") != nil,editor(app) == nil else {dump(app);fatalError("Double-click rename save failed")}
capture("workspace-double-click-renamed")
doubleClickTitle("双击修改标题")
replaceDraft("Must not save")
key(53)
guard find(app,"双击修改标题") != nil,find(app,"Must not save") == nil,editor(app) == nil else {dump(app);fatalError("Escape did not cancel")}
doubleClickTitle("双击修改标题")
replaceDraft("Saved on blur")
// Clicking the menu bar removes keyboard focus without changing workspace.
press(cycle)
guard find(app,"Saved on blur") == nil else {fatalError("Compact sidebar unexpectedly contains a title")}
press(cycle);press(cycle)
guard find(app,"Saved on blur") != nil,editor(app) == nil else {dump(app);fatalError("Blur did not save")}
capture("workspace-rename-blur-saved")
print("PASS: real title double-click, Chinese rename, Enter save, Escape cancel, repeated edits and sidebar-collapse commit")
guard let settings=find(menu,"设置…") ?? find(menu,"Settings…") else { dump(menu);fatalError("Missing settings") }
press(settings)
guard let appearance=find(app,"外观") else { dump(app);fatalError("Missing appearance") }
press(appearance)
dump(app)
guard find(app,"应用图标") != nil, find(app,"珍珠图标") != nil,find(app,"棉花糖图标") != nil else { fatalError("Chinese icon names missing") }
guard find(app,"App Icon") == nil, find(app,"Pearl app icon") == nil else {fatalError("English icon labels leaked")}
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
if [[ "$rc" != 0 ]]; then /usr/sbin/screencapture -x "$OUT/failure.png" || true; fi
cat "$OUT/RESULT.txt"
[[ "$rc" == 0 ]] && codesign --verify --deep --strict "$APP"
exit "$rc"
