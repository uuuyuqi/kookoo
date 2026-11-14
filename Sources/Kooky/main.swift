import AppKit
import KookyKit

CrashForensics.install()
let app = NSApplication.shared
AppIconController.shared.restoreAtLaunch()
let delegate = AppDelegate()
app.delegate = delegate
app.run()
