import AppKit
import ApplicationServices
import CoreGraphics

/// Tracks the two permissions bar-helper needs (REQ-X02) and drives the
/// low-friction, clearly-explained request flow that Ice was criticized for
/// lacking (REQ-I05):
///
/// * **Screen Recording** — to read the menu-bar layout and apply styling.
///   bar-helper does **not** record the screen, and the request copy says so.
/// * **Accessibility** — to move and interact with menu-bar items.
///
/// Missing permission never crashes the app; callers degrade gracefully.
final class PermissionsManager: ObservableObject {

    @Published private(set) var hasScreenRecording = false
    @Published private(set) var hasAccessibility = false

    /// True only when every capability is granted. When false, the app runs in
    /// a clearly-degraded mode rather than failing.
    var isFullyEnabled: Bool { hasScreenRecording && hasAccessibility }

    func refresh() {
        // `CGPreflightScreenCaptureAccess` checks without prompting.
        hasScreenRecording = CGPreflightScreenCaptureAccess()
        hasAccessibility = AXIsProcessTrusted()
    }

    /// Ask for Screen Recording. We never record the screen; access is only
    /// used to read menu-bar geometry and apply styling.
    func requestScreenRecording() {
        // Triggers the system prompt the first time; subsequent calls are
        // no-ops until the user changes the setting in System Settings.
        _ = CGRequestScreenCaptureAccess()
        refresh()
    }

    /// Ask for Accessibility, surfacing the system prompt with our explanation.
    func requestAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        hasAccessibility = AXIsProcessTrustedWithOptions(options)
    }

    /// Open the relevant System Settings pane so the user can grant or revoke
    /// access at any time.
    func openSystemSettings(for permission: Permission) {
        let urlString: String
        switch permission {
        case .screenRecording:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        case .accessibility:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        }
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    enum Permission {
        case screenRecording
        case accessibility
    }
}
