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
// Drag the real accessibility-labelled edge across the full/compact threshold
// in both directions. Keep the window geometry unchanged throughout.
func rect(_ e:AXUIElement) -> CGRect {
 guard let pv=value(e,kAXPositionAttribute),let sv=value(e,kAXSizeAttribute) else {fatalError("Missing geometry")}
 var p=CGPoint.zero;var z=CGSize.zero
 guard AXValueGetValue(pv as! AXValue,.cgPoint,&p),AXValueGetValue(sv as! AXValue,.cgSize,&z) else {fatalError("Invalid geometry")}
 return CGRect(origin:p,size:z)
}
func edge() -> CGRect {
 guard let e=find(app,"Resize workspace sidebar") else {dump(app);fatalError("Missing sidebar resize handle")}
 return rect(e)
}
func dragEdge(by delta:CGFloat) {
 let r=edge();let start=CGPoint(x:r.midX,y:r.midY)
 CGEvent(mouseEventSource:nil,mouseType:.leftMouseDown,mouseCursorPosition:start,mouseButton:.left)!.post(tap:.cghidEventTap)
 for n in 1...24 {
  let p=CGPoint(x:start.x+delta*CGFloat(n)/24,y:start.y)
  CGEvent(mouseEventSource:nil,mouseType:.leftMouseDragged,mouseCursorPosition:p,mouseButton:.left)!.post(tap:.cghidEventTap)
  Thread.sleep(forTimeInterval:0.08)
  if n % 4 == 0 {
   let expected=max(originalEdge-168,min(originalEdge+260,p.x))
   guard abs(edge().midX-expected)<3 else {dump(app);fatalError("Sidebar skipped intermediate drag width: expected \(expected), actual \(edge().midX)")}
  }
 }
 let end=CGPoint(x:start.x+delta,y:start.y)
 CGEvent(mouseEventSource:nil,mouseType:.leftMouseUp,mouseCursorPosition:end,mouseButton:.left)!.post(tap:.cghidEventTap)
 Thread.sleep(forTimeInterval:0.8)
}
guard let windows=value(app,kAXWindowsAttribute) as? [AXUIElement],let window=windows.first else {fatalError("Missing app window")}
let windowBefore=rect(window)
let originalEdge=edge().midX
dragEdge(by:100)
let wideEdge=edge().midX
guard abs(wideEdge-originalEdge-100)<3 else {fatalError("Failed to widen sidebar")}
dragEdge(by:-270)
guard find(app,"Saved on blur") == nil,abs(edge().midX-originalEdge+168)<3 else {dump(app);fatalError("Drag did not reach 52pt icon rail")}
capture("sidebar-drag-compact")
// The icon rail remains draggable and the same gesture crosses the threshold.
dragEdge(by:220)
guard find(app,"Saved on blur") != nil,abs(edge().midX-originalEdge-52)<3 else {fatalError("Cannot drag icon rail open")}
capture("sidebar-drag-expanded")
// Widen to 320 again, then shrink: Command+B must recover that saved width.
dragEdge(by:48);dragEdge(by:-270)
key(11,flags:.maskCommand);key(11,flags:.maskCommand)
guard find(app,"Saved on blur") != nil,abs(edge().midX-wideEdge)<3 else {fatalError("Command+B lost expanded width after drag")}
guard rect(window)==windowBefore else {fatalError("Sidebar drag moved/resized window")}
// Stop at intermediate widths in each direction, checking both live tracking
// (inside dragEdge) and the settled edge after mouse-up. No end-of-drag snap.
var currentWidth:CGFloat=320
for target:CGFloat in [200,160,120,80,52,80,120,160,200,320] {
 dragEdge(by:target-currentWidth)
 guard abs(edge().midX-(originalEdge+target-220))<3 else {fatalError("Sidebar snapped on mouse-up at \(target)")}
 currentWidth=target
 if [80,120,160].contains(target) {capture("sidebar-continuous-\(Int(target))")}
}
guard rect(window)==windowBefore else {fatalError("Continuous sidebar drag moved/resized window")}
print("PASS: intermediate widths track pointer continuously and remain unchanged on release in both directions")
print("PASS: real bidirectional sidebar drag to 52pt rail, retained expanded width, Command+B compatibility and stable window geometry")
// Multiple real workspace rows, including a harness-status icon. Emit only
// the documented OSC status marker in an isolated shell; do not run an agent.
func typeShell(_ text:String, at target:CGPoint? = nil, screenshot:String? = nil, focus:Bool = true) {
 // Return keyboard focus to the terminal after the inline rename editor.
 let w=rect(window),e=edge()
 let point=target ?? CGPoint(x:(e.maxX+w.maxX)/2,y:w.midY)
 if focus {
  for type in [CGEventType.leftMouseDown,.leftMouseUp] {
   CGEvent(mouseEventSource:nil,mouseType:type,mouseCursorPosition:point,mouseButton:.left)!.post(tap:.cghidEventTap)
  }
  Thread.sleep(forTimeInterval:0.3)
 }
 // CGEvent Unicode payloads are bounded: send small chunks so a long
 // printf command is not silently truncated before the OSC marker closes.
 let chars=Array(text.utf16)
 for start in stride(from:0,to:chars.count,by:8) {
  let chunk=Array(chars[start..<min(start+8,chars.count)])
  for down in [true,false] {
   let e=CGEvent(keyboardEventSource:nil,virtualKey:0,keyDown:down)!
   e.keyboardSetUnicodeString(stringLength:chunk.count,unicodeString:chunk);e.postToPid(pid)
  }
  Thread.sleep(forTimeInterval:0.08)
 }
 if let screenshot {capture(screenshot)}
 key(36)
}
func addNamedWorkspace(_ name:String) {
 guard let item=find(menu,"新建工作区") else {fatalError("Missing new workspace menu")}
 press(item);key(15,flags:[.maskCommand,.maskShift]);replaceDraft(name);key(36)
}
addNamedWorkspace("Harness fixture")
typeShell("printf '\\033]2;kookoo-agent:codex:running\\007'; sleep 90", screenshot:"harness-command-before-return")
Thread.sleep(forTimeInterval:1)
capture("harness-command-after-return")
addNamedWorkspace("Another terminal")
func matching(_ e:AXUIElement,_ predicate:(AXUIElement)->Bool) -> [AXUIElement] {
 var result=predicate(e) ? [e] : []
 for c in children(e) {result += matching(c,predicate)}
 return result
}
func checkCompactIcons() {
 let left=windowBefore.minX
 for name in ["Saved on blur","Harness fixture","Another terminal"] {
  guard let icon=find(app,"Workspace icon: "+name) else {dump(app);fatalError("Missing icon "+name)}
  let r=rect(icon)
  guard abs(r.midX-(left+26))<1.5,r.minX>=left+3,r.maxX<=left+49 else {dump(app);fatalError("Off-center/clipped icon "+name+" "+String(describing:r))}
  if name=="Harness fixture" {
   guard (value(icon,kAXIdentifierAttribute) as? String)=="workspace-icon-codex" else {dump(app);fatalError("Harness status icon missing")}
  }
 }
 let rows=matching(app) { (value($0,kAXIdentifierAttribute) as? String)?.hasPrefix("workspace-row-")==true }
 guard rows.count>=3 else {dump(app);fatalError("Missing workspace row geometry")}
 for row in rows {
  let r=rect(row)
  guard r.minX>=left+3,r.maxX<=left+49 else {fatalError("Compact card clipped: "+String(describing:r))}
 }
}
for round in 1...2 {
 dragEdge(by:-268);checkCompactIcons();capture("compact-multi-harness-\(round)")
 dragEdge(by:268)
}
key(11,flags:.maskCommand);checkCompactIcons();capture("compact-multi-harness-keyboard")
key(11,flags:.maskCommand);key(11,flags:.maskCommand)
print("PASS: multiple compact workspace cards and terminal/harness icons fully visible and centered after bidirectional drag and keyboard cycling")
// Click actual toolbar controls and use real shell markers to check new-pane
// focus plus continuity of the original libghostty terminal after collapse.
func toolbar(_ name:String) -> [AXUIElement] {
 matching(window) { labels($0).contains(name) && value($0,kAXRoleAttribute) as? String == kAXButtonRole }
     .sorted { rect($0).midX < rect($1).midX }
}
func oneToolbar(_ name:String) -> AXUIElement {
 let buttons=toolbar(name)
 guard buttons.count == 1, let button=buttons.first else {dump(window);fatalError("Expected one visible "+name)}
 return button
}
func shellMarker(_ name:String) -> String? {
 guard let home=ProcessInfo.processInfo.environment["HOME"] else {fatalError("Missing isolated HOME")}
 let path=home+"/"+name
 for _ in 0..<20 {
  if let value=try? String(contentsOfFile:path,encoding:.utf8),!value.isEmpty {return value}
  Thread.sleep(forTimeInterval:0.2)
 }
 return nil
}
let splitName="向右拆分（⌘D）"
let zoomName="缩放窗格（⌘⇧E）"
let restoreName="退出缩放（⌘⇧E）"
// Cmd+T yields a normal terminal, even when the add button opens a picker.
key(17,flags:.maskCommand)
key(18,flags:.maskCommand)
capture("ghostty-tab-rail")
typeShell("tty > \"$HOME/kookoo-pane-before\"")
guard let originalTTY=shellMarker("kookoo-pane-before") else {fatalError("Original terminal did not accept keyboard input")}
press(oneToolbar(splitName))
let splits=toolbar(splitName),zooms=toolbar(zoomName)
guard splits.count==2, zooms.count==2, rect(splits[0]).midX+40 < rect(splits[1]).midX,
      abs(rect(splits[0]).midY-rect(splits[1]).midY)<3,rect(window)==windowBefore else {
 dump(window);fatalError("Toolbar did not create a right-hand split")
}
typeShell("tty > \"$HOME/kookoo-pane-right\"",focus:false)
guard let rightTTY=shellMarker("kookoo-pane-right"),rightTTY != originalTTY else {
 dump(window);fatalError("New right terminal was not focused after toolbar split")
}
capture("ghostty-pane-split")
let originalZoomX=rect(zooms[0]).midX
press(zooms[0])
let restore=oneToolbar(restoreName)
_ = oneToolbar(splitName)
guard rect(restore).midX > originalZoomX+40,rect(window)==windowBefore else {
 fatalError("Zoom did not expand the left pane without resizing the window")
}
capture("ghostty-pane-zoomed")
press(restore)
guard toolbar(zoomName).count==2,toolbar(splitName).count==2 else {dump(window);fatalError("Restore did not reveal both panes")}
let terminalRight=CGPoint(x:rect(toolbar(splitName)[1]).midX-48,y:rect(window).midY)
typeShell("exit",at:terminalRight)
Thread.sleep(forTimeInterval:1.5)
_ = oneToolbar(splitName)
typeShell("tty > \"$HOME/kookoo-pane-after\"")
guard shellMarker("kookoo-pane-after")==originalTTY else {fatalError("Surviving Ghostty session lost its original tty or keyboard input")}
capture("ghostty-pane-restored")
print("PASS: Ghostty rail; AX-driven right split, focus, pane zoom/restore; original tty survives sibling exit")
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
guard let original=find(app,"Kookoo（默认）图标") else {dump(app);fatalError("Missing localized default icon")}
press(original)
guard iconBytes("AppIcon.icns") == iconBytes("IconChoices/default.icns") else {fatalError("Default restoration failed")}
guard find(app,"第 1 页，共 4 页") != nil || find(app,"1 / 4") != nil else {dump(app);fatalError("Missing first icon page indicator")}
guard let nextIconPage=find(app,"下一页图标") else {dump(app);fatalError("Missing next icon page")}
press(nextIconPage)
guard (find(app,"第 2 页，共 4 页") != nil || find(app,"2 / 4") != nil),
      find(app,"海洋图标") != nil, find(app,"珍珠图标") == nil else {dump(app);fatalError("Icon page 2 did not replace page 1")}
guard iconBytes("AppIcon.icns") == iconBytes("IconChoices/default.icns") else {fatalError("Paging changed the applied icon")}
capture("chinese-icons-page-2")
guard let previousIconPage=find(app,"上一页图标") else {dump(app);fatalError("Missing previous icon page")}
press(previousIconPage)
guard (find(app,"第 1 页，共 4 页") != nil || find(app,"1 / 4") != nil),
      find(app,"Kookoo（默认）图标") != nil, find(app,"海洋图标") == nil else {dump(app);fatalError("Could not return to icon page 1")}
guard iconBytes("AppIcon.icns") == iconBytes("IconChoices/default.icns") else {fatalError("Returning to page 1 changed the applied icon")}
print("PASS: Chinese icon settings, repeated selection, default restoration and icon pagination without selection changes verified; Command+B sent three times with screenshots for visual state verification.")
SWIFT
set +e
swift "$WORK/ui.swift" "$PID" "$OUT" "$APP" > "$OUT/RESULT.txt" 2>&1
rc=$?
set -e
if [[ "$rc" != 0 ]]; then /usr/sbin/screencapture -x "$OUT/failure.png" || true; fi
cat "$OUT/RESULT.txt"
[[ "$rc" == 0 ]] && codesign --verify --deep --strict "$APP"
exit "$rc"
