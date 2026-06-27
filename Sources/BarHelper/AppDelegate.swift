import AppKit
import Combine

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

    /// `barhelper://` automation entry point (REQ-A03).
    private lazy var urlScheme = URLSchemeHandler(commands: URLSchemeHandler.Commands(
        reveal: { [weak self] section in self?.menuBarManager.reveal(section) },
        hide: { [weak self] in self?.menuBarManager.hideAll() },
        toggle: { [weak self] section in self?.menuBarManager.toggle(section) },
        switchProfile: { [weak self] name in self?.settings.switchTo(named: name) }
    ))

    private let triggerEngine = TriggerEngine()
    private var triggerTimer: Timer?
    /// Triggers satisfied on the previous tick — used for false→true edge
    /// detection so a steadily-true trigger fires once, not every 30s.
    private var lastFiredTriggerIDs: Set<UUID> = []
    private var lastHotkeySignature = 0

    private var cancellables = Set<AnyCancellable>()

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
        observeHotkeyChanges()

        // Keep login-item registration in sync with the user's preference.
        LaunchAtLogin.shared.synchronize(enabled: settings.profile.launchAtLogin)

        // REQ-A03: enable URL-scheme automation if the profile allows it.
        if settings.profile.automation.urlSchemeEnabled {
            urlScheme.start()
        }

        // REQ-A01: evaluate automation triggers periodically.
        startTriggerEvaluation()
    }

    func applicationWillTerminate(_ notification: Notification) {
        triggerTimer?.invalidate()
        urlScheme.stop()
        menuBarManager.stop()
        hotkeys.unregisterAll()
    }

    // MARK: - Commands

    /// Opens the SwiftUI settings window (REQ-C04/C05/C06/C09).
    func openSettings() {
        settingsWindow.show()
    }

    // MARK: - Triggers (REQ-A01)

    private func startTriggerEvaluation() {
        // Evaluate on launch and then every 30s. Conditions are cheap to test;
        // the system snapshot is built fresh each tick.
        evaluateTriggers()
        triggerTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.evaluateTriggers()
        }
    }

    private func evaluateTriggers() {
        let triggers = settings.profile.triggers
        guard !triggers.isEmpty else { lastFiredTriggerIDs = []; return }
        let context = SystemState.liveContext()
        let fired = triggerEngine.firedTriggers(for: triggers, in: context)
        let firedIDs = Set(fired.map(\.id))

        // Only act on triggers that just became satisfied (false→true edge), so
        // a steadily-true trigger doesn't re-fire every tick.
        for trigger in fired where !lastFiredTriggerIDs.contains(trigger.id) {
            apply(trigger.action)
        }
        lastFiredTriggerIDs = firedIDs
    }

    private func apply(_ action: TriggerAction) {
        switch action.kind {
        case .showItems:
            // Automated edits skip undo history so triggers don't flood it.
            settings.update(recordHistory: false) { profile in
                for item in action.itemIDs { profile.sectionAssignments[item] = .visible }
            }
        case .hideItems:
            settings.update(recordHistory: false) { profile in
                for item in action.itemIDs { profile.sectionAssignments[item] = .hidden }
            }
        case .switchProfile:
            if let name = action.profileName { settings.switchTo(named: name) }
        }
    }

    // MARK: - Hotkeys (REQ-C07 / REQ-C18)

    /// Re-register hotkeys when the profile's bindings change, so edits in
    /// settings take effect without a relaunch.
    private func observeHotkeyChanges() {
        settings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                guard let self else { return }
                let signature = self.hotkeySignature()
                if signature != self.lastHotkeySignature {
                    self.lastHotkeySignature = signature
                    self.hotkeys.unregisterAll()
                    self.registerGlobalHotkeys()
                }
            }
            .store(in: &cancellables)
    }

    /// A cheap fingerprint of the bindings so we only re-register on real
    /// hotkey changes, not every settings tweak.
    private func hotkeySignature() -> Int {
        var hasher = Hasher()
        for b in settings.profile.hotkeys { hasher.combine(b.action); hasher.combine(b.keyCode); hasher.combine(b.modifiers) }
        for h in settings.profile.itemHotkeys { hasher.combine(h.itemID); hasher.combine(h.keyCode); hasher.combine(h.modifiers) }
        return hasher.finalize()
    }

    private func registerGlobalHotkeys() {
        lastHotkeySignature = hotkeySignature()
        for binding in settings.profile.hotkeys {
            hotkeys.register(binding) { [weak self] action in
                self?.perform(action)
            }
        }
        // REQ-C16: per-item hotkeys. Without a sanctioned API to surface one
        // specific other-app item, we reveal the section that item lives in —
        // a temporary reveal when the user opted into that.
        for itemHotkey in settings.profile.itemHotkeys {
            hotkeys.register(keyCode: itemHotkey.keyCode, modifiers: itemHotkey.modifiers) { [weak self] in
                guard let self else { return }
                let section = self.settings.profile.section(for: itemHotkey.itemID)
                self.menuBarManager.reveal(section == .visible ? .hidden : section)
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
        case .toggleSecondaryBar:
            menuBarManager.showHiddenItemsPanel()
        case .toggleSeparatorIcons:
            settings.update { $0.appearance.showDividerIcons.toggle() }
        case .toggleAppMenus:
            settings.update { $0.hideOverlappingAppMenus.toggle() }
        case .toggleAutoRehide:
            settings.update {
                $0.reveal.autoRehideDelay = $0.reveal.autoRehideDelay > 0 ? 0 : RevealSettings.default.autoRehideDelay
            }
        }
    }
}
