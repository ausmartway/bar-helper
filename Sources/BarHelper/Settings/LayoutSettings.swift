import Foundation

/// Menu-bar layout configuration (REQ-C12 / REQ-C15).
struct LayoutSettings: Codable, Equatable {
    /// Spacing, in points, between menu-bar items. Applied to the global
    /// `NSStatusItemSpacing` default by `SpacingManager`. The macOS default is
    /// ~16; lower values pack items more tightly (REQ-C12).
    var itemSpacing: Int

    /// Section that newly appearing menu-bar items are placed in by default
    /// (REQ-C15).
    var defaultSectionForNewItems: MenuBarSection

    /// On small screens, swap shown and hidden items to save space (REQ-C15).
    var swapShownHiddenOnSmallScreen: Bool

    static var `default`: LayoutSettings {
        LayoutSettings(
            itemSpacing: 16,
            defaultSectionForNewItems: .visible,
            swapShownHiddenOnSmallScreen: false
        )
    }
}

/// A custom spacer placed between menu-bar items to group them visually
/// (REQ-C13). The label may be plain text or an emoji.
///
/// Named `MenuBarSpacer` (not `Spacer`) to avoid shadowing SwiftUI's `Spacer`
/// view within this module.
struct MenuBarSpacer: Codable, Equatable, Identifiable {
    var id: UUID
    var label: String
    var section: MenuBarSection

    init(id: UUID = UUID(), label: String = "", section: MenuBarSection = .visible) {
        self.id = id
        self.label = label
        self.section = section
    }
}

/// Several menu-bar items combined into a single grouped control (REQ-C14).
struct ItemGroup: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var itemIDs: [String]

    init(id: UUID = UUID(), name: String, itemIDs: [String] = []) {
        self.id = id
        self.name = name
        self.itemIDs = itemIDs
    }
}

/// A hotkey bound to a specific menu-bar item (REQ-C16). When `temporaryReveal`
/// is set, pressing the hotkey shows the item briefly and then re-hides it
/// instead of permanently moving it to the visible section.
struct ItemHotkey: Codable, Equatable, Identifiable {
    var itemID: String
    var keyCode: UInt32
    var modifiers: UInt32
    var temporaryReveal: Bool

    var id: String { itemID }
}
