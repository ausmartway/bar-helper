import AppKit

/// Wires together the subsystems that make up bar-helper and owns their
/// lifetime. Kept deliberately thin: it constructs the collaborators and
/// forwards a few high-level commands. The real work lives in `MenuBarManager`.
final class AppDelegate: NSObject, NSApplicationDelegate {

    private let settings = SettingsStore()
    private let permissions = PermissionsManager()
    private lazy var hotkeys = HotkeyManager()
    private lazy var menuBarManager = MenuBarManager(
        settings: settings,
        permissions: permissions
    )
    private lazy var settingsWindow = SettingsWindowController(
        settings: settings,
        permissions: permissions,
        menuBarManager: menuBarManager
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        // REQ-B01: bar-helper ships no analytics. This call documents and
        // enforces that invariant at startup.
        Telemetry.assertDisabled()

        // REQ-I05: check permissions up front, but never block — the app runs
        // in a clearly-degraded mode when access is missing.
        permissions.refresh()

        menuBarManager.onOpenSettings = { [weak self] in self?.openSettings() }
        menuBarManager.start()
        registerGlobalHotkeys()

        // Keep login-item registration in sync with the user's preference.
        LaunchAtLogin.shared.synchronize(enabled: settings.profile.launchAtLogin)
    }

    func applicationWillTerminate(_ notification: Notification) {
        menuBarManager.stop()
        hotkeys.unregisterAll()
    }

    // MARK: - Commands

    /// Opens the SwiftUI settings window (REQ-C04/C05/C06/C09).
    func openSettings() {
        settingsWindow.show()
    }

    // MARK: - Hotkeys (REQ-C07)

    private func registerGlobalHotkeys() {
        for binding in settings.profile.hotkeys {
            hotkeys.register(binding) { [weak self] action in
                self?.perform(action)
            }
        }
    }

    private func perform(_ action: HotkeyAction) {
        switch action {
        case .toggleHidden:
            menuBarManager.toggle(.hidden)
        case .toggleAlwaysHidden:
            menuBarManager.toggle(.alwaysHidden)
        case .openSettings:
            openSettings()
        case .search:
            settingsWindow.show(focus: .search)
        }
    }
}
