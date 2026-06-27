import AppKit
import ApplicationServices

/// Handles overlap between revealed status items and the active app's menu
/// titles (REQ-C17).
///
/// When many items are revealed they extend left and can collide with the
/// focused app's menu bar titles, making them unclickable. This type measures
/// the frontmost app's menu extent via Accessibility so the overlap decision is
/// data-driven, and owns the shown/hidden transitions.
///
/// Limitation (REQ-X03): macOS exposes no sanctioned way to hide *another*
/// app's menu titles, so when overlap is detected bar-helper's honest response
/// is to record the condition (and, in the fuller build, prefer the secondary
/// Ice-Bar surface over expanding in place). The Accessibility *measurement*
/// below is real; the suppression of other apps' menus is intentionally not
/// faked.
final class AppMenuManager {

    /// User preference (REQ-C17). Mirrors `Profile.hideOverlappingAppMenus`.
    var isEnabled = false

    /// Set when the last reveal was found to overlap the app menus.
    private(set) var lastRevealOverlapped = false

    private var menusHidden = false

    /// Called when hidden items become visible.
    @discardableResult
    func itemsRevealed() -> Bool {
        guard isEnabled else { return false }
        lastRevealOverlapped = revealWouldOverlapMenus()
        menusHidden = lastRevealOverlapped
        return menusHidden
    }

    /// Called when items are hidden again.
    func itemsHidden() {
        menusHidden = false
        lastRevealOverlapped = false
    }

    // MARK: - Accessibility measurement (real)

    /// Heuristic: revealing overlaps the app menus when the frontmost app's
    /// menu titles extend past the right edge of the available menu-bar space
    /// the revealed items need. Without precise item geometry we use a
    /// conservative threshold on the menu width.
    private func revealWouldOverlapMenus() -> Bool {
        guard let width = frontmostMenuBarWidth(),
              let screenWidth = NSScreen.main?.frame.width else { return false }
        // If the app menus already span more than ~60% of the bar, revealing a
        // hidden cluster on top of them is very likely to overlap.
        return width > screenWidth * 0.6
    }

    /// Total width, in points, of the frontmost application's menu-bar titles,
    /// read via the Accessibility API. Returns nil without Accessibility access
    /// or when the menu bar can't be read.
    func frontmostMenuBarWidth() -> CGFloat? {
        guard AXIsProcessTrusted(),
              let app = NSWorkspace.shared.frontmostApplication else { return nil }

        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var menuBarRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXMenuBarAttribute as CFString, &menuBarRef) == .success,
              let menuBar = menuBarRef else { return nil }

        // `menuBar` is an AXUIElement; fetch its children (the menu titles).
        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(menuBar as! AXUIElement,
                                            kAXChildrenAttribute as CFString,
                                            &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement] else { return nil }

        var total: CGFloat = 0
        for child in children {
            var sizeRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(child, kAXSizeAttribute as CFString, &sizeRef) == .success,
                  let sizeValue = sizeRef else { continue }
            var size = CGSize.zero
            if AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) {
                total += size.width
            }
        }
        return total > 0 ? total : nil
    }
}
