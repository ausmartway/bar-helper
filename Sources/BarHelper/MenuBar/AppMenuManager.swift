import AppKit

/// Handles overlap between revealed status items and the active app's menu
/// titles (REQ-C17).
///
/// When many items are revealed they can extend left far enough to collide
/// with the focused app's menu bar titles, making them unclickable. With this
/// behavior enabled, bar-helper collapses the revealed region (or, in a fuller
/// implementation, shifts the app menus) while items are shown, and restores
/// the normal state when they hide again.
///
/// The precise app-menu manipulation requires Accessibility and is inherently
/// fragile across macOS versions (REQ-X03); this type owns the toggle and the
/// shown/hidden transitions so the behavior has a single, well-defined home.
final class AppMenuManager {

    /// User preference (REQ-C17). Mirrors `Profile.hideOverlappingAppMenus`.
    var isEnabled = false

    private var menusHidden = false

    /// Called when hidden items become visible. Returns whether the caller
    /// should treat the app menus as hidden for layout purposes.
    @discardableResult
    func itemsRevealed() -> Bool {
        guard isEnabled, !menusHidden else { return menusHidden }
        menusHidden = applyHidden(true)
        return menusHidden
    }

    /// Called when items are hidden again; restores the app menus.
    func itemsHidden() {
        guard menusHidden else { return }
        _ = applyHidden(false)
        menusHidden = false
    }

    /// Perform the actual hide/show. Kept isolated and best-effort: returns the
    /// resulting hidden state. Full Accessibility-based menu shifting is a
    /// follow-up; today this records intent and is the hook real manipulation
    /// will live behind, so the rest of the app can rely on the contract.
    private func applyHidden(_ hidden: Bool) -> Bool {
        // Intentionally conservative: we do not yet move other apps' menus via
        // Accessibility. The state transition is tracked so reveal/hide stays
        // balanced and the UI toggle is meaningful.
        return hidden
    }
}
