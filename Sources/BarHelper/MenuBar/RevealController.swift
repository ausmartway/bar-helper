import AppKit

/// Translates user gestures over the menu bar into reveal/hide commands and
/// owns the auto-rehide timer (REQ-C02 / REQ-C03).
///
/// The active triggers are driven entirely by the current profile's
/// `RevealSettings`, so toggling a checkbox in settings takes effect without
/// re-wiring anything.
final class RevealController {

    private let settings: SettingsStore
    private let onReveal: (MenuBarSection) -> Void
    private let onHideAll: () -> Void

    private var monitors: [Any] = []
    private var autoRehideTimer: Timer?

    /// How tall, in points, the strip along the top of the screen counts as
    /// "the menu bar" for hover/scroll gestures.
    private let menuBarHeight: CGFloat = 24

    init(settings: SettingsStore,
         onReveal: @escaping (MenuBarSection) -> Void,
         onHideAll: @escaping () -> Void) {
        self.settings = settings
        self.onReveal = onReveal
        self.onHideAll = onHideAll
    }

    // MARK: - Lifecycle

    func start() {
        installMonitors()
    }

    func stop() {
        cancelAutoRehide()
        removeMonitors()
    }

    /// Re-read settings (e.g. the user toggled hover/scroll). Cheap to call.
    func reloadSettings() {
        removeMonitors()
        installMonitors()
    }

    // MARK: - Auto-rehide (REQ-C03)

    func scheduleAutoRehide() {
        cancelAutoRehide()
        let delay = settings.profile.reveal.autoRehideDelay
        guard delay > 0 else { return }
        autoRehideTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.onHideAll()
        }
    }

    func cancelAutoRehide() {
        autoRehideTimer?.invalidate()
        autoRehideTimer = nil
    }

    // MARK: - Event monitors (REQ-C02)

    private func installMonitors() {
        let reveal = settings.profile.reveal

        // Click anywhere in the menu bar reveals hidden items.
        if reveal.onClick {
            addGlobalMonitor(for: [.leftMouseDown]) { [weak self] event in
                self?.handlePointerEvent(event)
            }
        }

        // Hover the menu bar to reveal.
        if reveal.onHover {
            addGlobalMonitor(for: [.mouseMoved]) { [weak self] event in
                self?.handlePointerEvent(event)
            }
        }

        // Scroll/swipe over the menu bar reveals (scroll up) or hides (down).
        if reveal.onScroll {
            addGlobalMonitor(for: [.scrollWheel]) { [weak self] event in
                self?.handleScroll(event)
            }
        }
    }

    private func addGlobalMonitor(for mask: NSEvent.EventTypeMask,
                                  handler: @escaping (NSEvent) -> Void) {
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler) {
            monitors.append(monitor)
        }
    }

    private func removeMonitors() {
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors.removeAll()
    }

    // MARK: - Gesture handling

    private func handlePointerEvent(_ event: NSEvent) {
        guard isInMenuBar(event) else { return }
        onReveal(.hidden)
    }

    private func handleScroll(_ event: NSEvent) {
        guard isInMenuBar(event) else { return }
        if event.scrollingDeltaY > 0.5 {
            onReveal(.hidden)
        } else if event.scrollingDeltaY < -0.5 {
            onHideAll()
        }
    }

    /// Is the event located within the menu-bar strip of the main screen?
    private func isInMenuBar(_ event: NSEvent) -> Bool {
        guard let screen = NSScreen.main else { return false }
        // `NSEvent.mouseLocation` is in screen coordinates with origin at the
        // bottom-left; the menu bar sits at the very top.
        let location = NSEvent.mouseLocation
        let top = screen.frame.maxY
        return location.y >= top - menuBarHeight && location.y <= top
    }
}
