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
