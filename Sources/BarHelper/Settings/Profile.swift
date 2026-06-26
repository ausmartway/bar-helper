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

    func section(for itemID: String) -> MenuBarSection {
        sectionAssignments[itemID] ?? .visible
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
