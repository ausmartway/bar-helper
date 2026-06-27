import Foundation

/// A named, switchable menu-bar configuration (REQ-C09 / REQ-I04).
///
/// Everything a user can configure lives here so a profile fully captures a
/// layout and can be round-tripped through `Codable` (REQ-X: single source of
/// truth shared between the AppKit controller and the SwiftUI settings views).
struct Profile: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String

    /// Assignment of individual menu-bar items to sections, keyed by a stable
    /// item identifier (bundle id + title). Items not listed default to
    /// `.visible`.
    var sectionAssignments: [String: MenuBarSection]

    /// Reveal behavior (REQ-C02 / REQ-C03).
    var reveal: RevealSettings

    /// Menu-bar styling (REQ-C05).
    var appearance: Appearance

    /// Global hotkeys (REQ-C07).
    var hotkeys: [HotkeyBinding]

    /// Launch at login (REQ-C08).
    var launchAtLogin: Bool

    /// Layout: spacing + default placement (REQ-C12 / REQ-C15).
    var layout: LayoutSettings = .default

    /// Custom spacer items (REQ-C13).
    var spacers: [MenuBarSpacer] = []

    /// Grouped items (REQ-C14).
    var groups: [ItemGroup] = []

    /// Per-item hotkeys + temporary reveal (REQ-C16).
    var itemHotkeys: [ItemHotkey] = []

    /// Automation triggers (REQ-A01).
    var triggers: [Trigger] = []

    /// Automation surface toggles (REQ-A02 / REQ-A03).
    var automation: AutomationSettings = .default

    /// Hide the active app's menus when revealed items overlap them (REQ-C17).
    var hideOverlappingAppMenus: Bool = false

    /// Optional dark-mode appearance override (REQ-C20). When nil, `appearance`
    /// is used in both light and dark.
    var darkAppearance: Appearance?

    /// Apply distinct styling per display/Space (REQ-C20). Full per-display
    /// mapping is a follow-up; this flag gates the behavior.
    var perDisplayStyling: Bool = false

    // Memberwise init is synthesized and used by `Profile.default`.
    init(id: UUID, name: String, sectionAssignments: [String: MenuBarSection],
         reveal: RevealSettings, appearance: Appearance, hotkeys: [HotkeyBinding],
         launchAtLogin: Bool, layout: LayoutSettings = .default,
         spacers: [MenuBarSpacer] = [], groups: [ItemGroup] = [],
         itemHotkeys: [ItemHotkey] = [], triggers: [Trigger] = [],
         automation: AutomationSettings = .default, hideOverlappingAppMenus: Bool = false,
         darkAppearance: Appearance? = nil, perDisplayStyling: Bool = false) {
        self.id = id
        self.name = name
        self.sectionAssignments = sectionAssignments
        self.reveal = reveal
        self.appearance = appearance
        self.hotkeys = hotkeys
        self.launchAtLogin = launchAtLogin
        self.layout = layout
        self.spacers = spacers
        self.groups = groups
        self.itemHotkeys = itemHotkeys
        self.triggers = triggers
        self.automation = automation
        self.hideOverlappingAppMenus = hideOverlappingAppMenus
        self.darkAppearance = darkAppearance
        self.perDisplayStyling = perDisplayStyling
    }

    /// Back-compatible decoder: fields added after v1 fall back to their
    /// defaults when absent, so a profile persisted by an older build still
    /// loads instead of being silently discarded.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        sectionAssignments = try c.decode([String: MenuBarSection].self, forKey: .sectionAssignments)
        reveal = try c.decode(RevealSettings.self, forKey: .reveal)
        appearance = try c.decode(Appearance.self, forKey: .appearance)
        hotkeys = try c.decode([HotkeyBinding].self, forKey: .hotkeys)
        launchAtLogin = try c.decode(Bool.self, forKey: .launchAtLogin)
        layout = try c.decodeIfPresent(LayoutSettings.self, forKey: .layout) ?? .default
        spacers = try c.decodeIfPresent([MenuBarSpacer].self, forKey: .spacers) ?? []
        groups = try c.decodeIfPresent([ItemGroup].self, forKey: .groups) ?? []
        itemHotkeys = try c.decodeIfPresent([ItemHotkey].self, forKey: .itemHotkeys) ?? []
        triggers = try c.decodeIfPresent([Trigger].self, forKey: .triggers) ?? []
        automation = try c.decodeIfPresent(AutomationSettings.self, forKey: .automation) ?? .default
        hideOverlappingAppMenus = try c.decodeIfPresent(Bool.self, forKey: .hideOverlappingAppMenus) ?? false
        darkAppearance = try c.decodeIfPresent(Appearance.self, forKey: .darkAppearance)
        perDisplayStyling = try c.decodeIfPresent(Bool.self, forKey: .perDisplayStyling) ?? false
    }

    func section(for itemID: String) -> MenuBarSection {
        sectionAssignments[itemID] ?? .visible
    }

    /// The appearance to use for the given interface style (REQ-C20).
    func appearance(forDarkMode isDark: Bool) -> Appearance {
        (isDark ? darkAppearance : nil) ?? appearance
    }

    static var `default`: Profile {
        Profile(
            id: UUID(),
            name: "Default",
            sectionAssignments: [:],
            reveal: .default,
            appearance: .default,
            hotkeys: HotkeyBinding.defaults,
            launchAtLogin: false
        )
    }
}

/// How and when hidden items are revealed and re-hidden.
struct RevealSettings: Codable, Equatable {
    var onClick: Bool
    var onHover: Bool
    var onScroll: Bool
    /// Seconds of inactivity before revealed items auto-hide (REQ-C03).
    /// `0` disables auto-rehide.
    var autoRehideDelay: TimeInterval

    static var `default`: RevealSettings {
        RevealSettings(onClick: true, onHover: false, onScroll: true, autoRehideDelay: 6)
    }
}
