import AppKit
import Combine

/// The heart of bar-helper. Owns the separator status items, tracks which
/// section is revealed, and coordinates the reveal triggers and auto-rehide
/// timer (REQ-C01..C04, C10).
final class MenuBarManager: ObservableObject {

    private let settings: SettingsStore
    private let permissions: PermissionsManager

    /// Invoked when the user picks "Settings…" from the control menu. Wired up
    /// by `AppDelegate`, which owns the settings window.
    var onOpenSettings: (() -> Void)?

    /// The always-visible primary item and its menu.
    private var controlItem: ControlItem?

    /// One separator per bounded section (`.hidden`, `.alwaysHidden`).
    private var separators: [MenuBarSection: Separator] = [:]

    private lazy var revealController = RevealController(
        settings: settings,
        onReveal: { [weak self] section in self?.reveal(section) },
        onHideAll: { [weak self] in self?.hideAll() }
    )

    /// Optional Ice-Bar-style popover listing hidden items (REQ-C10).
    private lazy var barPanel = HiddenItemsPanel(settings: settings)

    /// Hides the active app's menus when revealed items overlap them (REQ-C17).
    let appMenuManager = AppMenuManager()

    /// Renders the menu-bar styling overlay (REQ-C05/C20/C21).
    private lazy var styleManager = MenuBarStyleManager(settings: settings)

    /// Renders spacers (REQ-C13) and group placeholders (REQ-C14).
    private let spacerController = SpacerController()

    /// Temporary reveal on activity (REQ-A02).
    private let activityMonitor = ActivityMonitor()

    @Published private(set) var revealedSection: MenuBarSection?

    private var cancellables = Set<AnyCancellable>()

    init(settings: SettingsStore, permissions: PermissionsManager) {
        self.settings = settings
        self.permissions = permissions
    }

    // MARK: - Lifecycle

    func start() {
        controlItem = ControlItem(commands: ControlItem.Commands(
            openSettings: { [weak self] in self?.onOpenSettings?() },
            toggleHidden: { [weak self] in self?.toggle(.hidden) },
            showHiddenBar: { [weak self] in self?.showHiddenItemsPanel() },
            quit: { NSApp.terminate(nil) }
        ))

        for section in MenuBarSection.separatorSections {
            separators[section] = Separator(section: section) { [weak self] in
                self?.toggle(section)
            }
        }
        spacerController.onGroupActivated = { [weak self] section in self?.reveal(section) }
        activityMonitor.onActivity = { [weak self] in
            guard let self, self.settings.profile.automation.temporaryRevealOnActivity else { return }
            self.reveal(.hidden)
        }

        // Start in the tidy state: everything hidden.
        applyProfileSettings()
        styleManager.start()
        activityMonitor.start()
        hideAll()
        revealController.start()

        // React to profile/reveal-setting changes. `objectWillChange` fires
        // *before* the @Published value is stored, so hop to the next runloop
        // tick to read the post-mutation profile (avoids applying one edit
        // late).
        settings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                self?.revealController.reloadSettings()
                self?.applyProfileSettings()
            }
            .store(in: &cancellables)
    }

    /// Push profile-driven settings into the AppKit collaborators
    /// (REQ-C12/C17/C19).
    private func applyProfileSettings() {
        appMenuManager.isEnabled = settings.profile.hideOverlappingAppMenus
        // Only write the system-wide spacing override when the user actually
        // customized it; otherwise clear any override so we don't pollute the
        // global domain for every app (and restore it on stop()).
        let spacing = settings.profile.layout.itemSpacing
        if spacing == LayoutSettings.default.itemSpacing {
            SpacingManager.reset()
        } else {
            SpacingManager.apply(spacing: spacing)
        }
        let appearance = settings.profile.appearance
        for separator in separators.values {
            separator.setIcon(symbol: appearance.separatorIconSymbol,
                              visible: appearance.showDividerIcons)
        }
        styleManager.refresh()
        spacerController.sync(spacers: settings.profile.spacers,
                              groups: settings.profile.groups)
    }

    func stop() {
        revealController.stop()
        styleManager.stop()
        activityMonitor.stop()
        SpacingManager.reset() // don't leave a global spacing override behind
        spacerController.clear()
        separators.values.forEach { $0.dispose() }
        separators.removeAll()
        controlItem?.dispose()
        controlItem = nil
    }

    // MARK: - Reveal / hide (REQ-C01/C02)

    func toggle(_ section: MenuBarSection) {
        if revealedSection == section {
            hideAll()
        } else {
            reveal(section)
        }
    }

    func reveal(_ section: MenuBarSection) {
        // `.alwaysHidden` implies `.hidden` must also be revealed, since it
        // sits further left.
        revealedSection = section
        separators[.hidden]?.setRevealed(true)
        separators[.alwaysHidden]?.setRevealed(section == .alwaysHidden)
        appMenuManager.itemsRevealed() // REQ-C17
        revealController.scheduleAutoRehide()
    }

    func hideAll() {
        revealedSection = nil
        separators[.hidden]?.setRevealed(false)
        separators[.alwaysHidden]?.setRevealed(false)
        appMenuManager.itemsHidden() // REQ-C17
        revealController.cancelAutoRehide()
    }

    /// Show the secondary panel listing hidden items (REQ-C10) — an
    /// alternative to expanding the main bar.
    func showHiddenItemsPanel() {
        barPanel.toggle()
    }
}
