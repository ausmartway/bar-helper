import Foundation

/// The three sections that divide the menu bar (REQ-C01).
///
/// Items to the right of the `hidden` separator are always visible. Items
/// between the `hidden` and `alwaysHidden` separators are revealed on demand.
/// Items to the left of the `alwaysHidden` separator stay concealed unless the
/// user explicitly asks for them.
enum MenuBarSection: String, Codable, CaseIterable, Identifiable {
    case visible
    case hidden
    case alwaysHidden

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .visible: return "Visible"
        case .hidden: return "Hidden"
        case .alwaysHidden: return "Always Hidden"
        }
    }

    /// Sections that own a separator status item. `.visible` has no separator
    /// of its own — it is simply "everything to the right of `hidden`".
    static var separatorSections: [MenuBarSection] { [.hidden, .alwaysHidden] }
}
