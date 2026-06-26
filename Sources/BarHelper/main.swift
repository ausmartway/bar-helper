import AppKit

// Entry point for bar-helper.
//
// bar-helper is a menu-bar agent: it has no Dock icon and no main window
// (the SwiftUI settings window is opened on demand). `.accessory` activation
// policy is the runtime equivalent of the LSUIElement / "Application is agent"
// Info.plist key documented in CLAUDE.md.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
