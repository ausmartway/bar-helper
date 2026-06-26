import Foundation
import Carbon.HIToolbox

/// A user action that can be bound to a global hotkey (REQ-C07).
enum HotkeyAction: String, Codable, CaseIterable, Identifiable {
    case toggleHidden
    case toggleAlwaysHidden
    case openSettings
    case search
    // Expanded actions (REQ-C18).
    case toggleSecondaryBar
    case toggleSeparatorIcons
    case toggleAppMenus
    case toggleAutoRehide

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .toggleHidden: return "Toggle Hidden Items"
        case .toggleAlwaysHidden: return "Toggle Always-Hidden Items"
        case .openSettings: return "Open Settings"
        case .search: return "Search Menu Bar Items"
        case .toggleSecondaryBar: return "Toggle Hidden Items Bar"
        case .toggleSeparatorIcons: return "Show/Hide Separator Icons"
        case .toggleAppMenus: return "Toggle Application Menus"
        case .toggleAutoRehide: return "Toggle Auto-Rehide"
        }
    }
}

/// A global hotkey binding: an action plus the Carbon key code and modifier
/// mask used to register it with `RegisterEventHotKey`.
struct HotkeyBinding: Codable, Equatable, Identifiable {
    var action: HotkeyAction
    /// Carbon virtual key code (e.g. `kVK_ANSI_B`).
    var keyCode: UInt32
    /// Carbon modifier flags (e.g. `cmdKey | optionKey`).
    var modifiers: UInt32

    var id: String { action.rawValue }

    /// Sensible out-of-the-box bindings so the app is usable before the user
    /// customizes anything.
    static var defaults: [HotkeyBinding] {
        [
            HotkeyBinding(
                action: .toggleHidden,
                keyCode: UInt32(kVK_ANSI_B),
                modifiers: UInt32(cmdKey | optionKey)
            ),
            HotkeyBinding(
                action: .search,
                keyCode: UInt32(kVK_ANSI_F),
                modifiers: UInt32(cmdKey | optionKey)
            )
        ]
    }
}
