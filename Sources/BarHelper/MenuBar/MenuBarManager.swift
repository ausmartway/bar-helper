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
        // Start in the tidy state: everything hidden.
        hideAll()
        revealController.start()

        // React to profile/reveal-setting changes without duplicating state.
        settings.objectWillChange
            .sink { [weak self] in self?.revealController.reloadSettings() }
            .store(in: &cancellables)
    }

    func stop() {
        revealController.stop()
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
        revealController.scheduleAutoRehide()
    }

    func hideAll() {
        revealedSection = nil
        separators[.hidden]?.setRevealed(false)
        separators[.alwaysHidden]?.setRevealed(false)
        revealController.cancelAutoRehide()
    }

    /// Show the secondary panel listing hidden items (REQ-C10) — an
    /// alternative to expanding the main bar.
    func showHiddenItemsPanel() {
        barPanel.toggle()
    }
}
