import AppKit
import SwiftUI

/// Hosts the SwiftUI settings window inside this AppKit agent app. The window
/// is created lazily and reused; opening it briefly promotes the app to a
/// regular activation policy so the window can take focus, then drops back to
/// `.accessory` when closed.
final class SettingsWindowController: NSObject, NSWindowDelegate {

    /// Which pane/control should receive focus when the window opens.
    enum Focus {
        case general
        case search
    }

    private let settings: SettingsStore
    private let permissions: PermissionsManager
    private let menuBarManager: MenuBarManager
    private var window: NSWindow?

    init(settings: SettingsStore,
         permissions: PermissionsManager,
         menuBarManager: MenuBarManager) {
        self.settings = settings
        self.permissions = permissions
        self.menuBarManager = menuBarManager
        super.init()
    }

    func show(focus: Focus = .general) {
        permissions.refresh()

        let window = self.window ?? makeWindow()
        self.window = window

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.center()
    }

    private func makeWindow() -> NSWindow {
        let root = SettingsView(
            settings: settings,
            permissions: permissions,
            onShowHiddenPanel: { [weak menuBarManager] in
                menuBarManager?.showHiddenItemsPanel()
            }
        )
        let hosting = NSHostingController(rootView: root)
        let window = NSWindow(contentViewController: hosting)
        window.title = "bar-helper Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 640, height: 520))
        window.isReleasedWhenClosed = false
        window.delegate = self
        return window
    }

    // Drop back to agent (no Dock icon) once settings closes.
    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
