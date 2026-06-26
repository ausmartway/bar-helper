import AppKit

/// One separator (chevron) status item that bounds a menu-bar section
/// (REQ-C01). This is the mechanism that actually hides items:
///
/// macOS lays out status items right-to-left. The items belonging to *other*
/// apps sit to the **left** of our separator. When the separator's `length` is
/// expanded to a very large value it consumes the menu bar's width and pushes
/// everything to its left off the visible edge of the screen — the items are
/// not destroyed, merely shoved out of view. Collapsing the length back to the
/// chevron's natural width reveals them again.
final class Separator {

    /// Width, in points, the item occupies when its section is revealed
    /// (just the chevron glyph).
    private static let revealedWidth: CGFloat = 24

    /// Width used to push neighboring items off-screen. Comfortably wider than
    /// any real display so the hidden items always clear the left edge.
    private static let hiddenWidth: CGFloat = 10_000

    let section: MenuBarSection
    private let statusItem: NSStatusItem
    private var onClick: (() -> Void)?

    /// Whether the section bounded by this separator is currently revealed.
    private(set) var isRevealed: Bool = false

    init(section: MenuBarSection, onClick: @escaping () -> Void) {
        self.section = section
        self.onClick = onClick
        self.statusItem = NSStatusBar.system.statusItem(withLength: Separator.hiddenWidth)
        configureButton()
        apply()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.image = chevronImage(pointingLeft: true)
        button.imagePosition = .imageOnly
        button.target = self
        button.action = #selector(buttonClicked)
        // Receive both left and right clicks so the reveal controller can
        // distinguish gestures later if needed.
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = "\(section.displayName) — click to reveal/hide"
    }

    @objc private func buttonClicked() {
        onClick?()
    }

    /// Reveal or hide the section this separator bounds.
    func setRevealed(_ revealed: Bool) {
        guard revealed != isRevealed else { return }
        isRevealed = revealed
        apply()
    }

    private func apply() {
        statusItem.length = isRevealed ? Separator.revealedWidth : Separator.hiddenWidth
        statusItem.button?.image = chevronImage(pointingLeft: !isRevealed)
    }

    /// Remove the status item from the menu bar.
    func dispose() {
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    private func chevronImage(pointingLeft: Bool) -> NSImage? {
        let name = pointingLeft ? "chevron.left" : "chevron.right"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: section.displayName)
        image?.isTemplate = true
        return image
    }
}
