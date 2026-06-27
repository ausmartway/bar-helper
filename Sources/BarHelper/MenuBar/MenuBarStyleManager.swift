import AppKit

/// Renders the menu-bar styling (REQ-C05/C20/C21) by placing a borderless
/// overlay window over each screen's menu-bar strip and drawing the tint,
/// border, shadow, corners, and background onto it.
///
/// One overlay per screen supports per-display styling (REQ-C20). The manager
/// re-applies on screen-configuration changes and on light/dark switches.
///
/// Limitation: a pixel-perfect tint *behind* the system's own menu-bar
/// rendering requires the screen-capture compositing approach Ice uses
/// (REQ-X02/X03). This overlay draws at the status-item window level — visible
/// and honest, but it sits with the icons rather than compositing beneath the
/// system bar. Documented so the behavior isn't mistaken for the full effect.
final class MenuBarStyleManager {

    private let settings: SettingsStore
    private var overlays: [StyleOverlayWindow] = []
    private var observers: [NSObjectProtocol] = []
    private var appearanceObservation: NSKeyValueObservation?

    init(settings: SettingsStore) {
        self.settings = settings
    }

    func start() {
        rebuild()
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main) { [weak self] _ in self?.rebuild() })

        // React to light/dark changes (REQ-C20).
        appearanceObservation = NSApp.observe(\.effectiveAppearance) { [weak self] _, _ in
            DispatchQueue.main.async { self?.apply() }
        }
    }

    func stop() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
        appearanceObservation = nil
        overlays.forEach { $0.orderOut(nil) }
        overlays.removeAll()
    }

    /// Re-apply styling without rebuilding windows (e.g. settings changed).
    func refresh() {
        apply()
    }

    // MARK: - Internal

    private func rebuild() {
        overlays.forEach { $0.orderOut(nil) }
        overlays = NSScreen.screens.compactMap { screen in
            guard StyleResolver.hasMenuBar(screenFrame: screen.frame,
                                           visibleFrame: screen.visibleFrame) else { return nil }
            let frame = StyleResolver.menuBarFrame(screenFrame: screen.frame,
                                                   visibleFrame: screen.visibleFrame)
            return StyleOverlayWindow(menuBarFrame: frame)
        }
        apply()
    }

    private func apply() {
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let appearance = StyleResolver.appearance(for: settings.profile, isDark: isDark)
        let visible = StyleResolver.needsOverlay(appearance)
        let perDisplay = settings.profile.perDisplayStyling

        for (index, overlay) in overlays.enumerated() {
            // With per-display styling off, every screen gets the same look.
            // With it on, secondary displays are left unstyled so the active
            // display reads as distinct (a simple, predictable rule).
            let show = visible && (!perDisplay || index == 0)
            overlay.update(appearance: show ? appearance : nil)
        }
    }
}

/// A click-through borderless window that draws the menu-bar styling.
final class StyleOverlayWindow: NSWindow {

    private let styleView = StyleView()

    init(menuBarFrame: CGRect) {
        super.init(contentRect: menuBarFrame, styleMask: .borderless,
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        level = .statusBar
        contentView = styleView
    }

    func update(appearance: Appearance?) {
        guard let appearance else { orderOut(nil); return }
        styleView.style = appearance
        styleView.needsDisplay = true
        orderFrontRegardless()
    }
}

/// Draws tint / border / shadow / corners for the overlay.
private final class StyleView: NSView {
    var style: Appearance?

    override var isFlipped: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard let appearance = style else { return }
        let radius = max(CGFloat(appearance.cornerRadius),
                         appearance.roundedScreenCorners ? 10 : 0)
        let path = NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius)

        if appearance.backgroundRemoval {
            NSColor.black.setFill()
            path.fill()
        }
        if let tint = appearance.tint {
            tint.nsColor.setFill()
            path.fill()
        }
        if appearance.hasBorder {
            appearance.borderColor.nsColor.setStroke()
            path.lineWidth = 2
            path.stroke()
        }
        if appearance.hasShadow {
            let shadow = NSShadow()
            shadow.shadowBlurRadius = 4
            shadow.shadowOffset = NSSize(width: 0, height: -1)
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.4)
            shadow.set()
        }
    }
}
