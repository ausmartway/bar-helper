import AppKit

/// Temporarily reveals hidden items in response to activity (REQ-A02).
///
/// True per-item "an icon just changed" detection requires continuously
/// screen-capturing the menu bar and diffing it (REQ-X02/X03) — heavy and
/// deferred. As an honest, lightweight stand-in this watches `NSWorkspace`
/// application-activation events as an activity signal and briefly reveals the
/// hidden section so a freshly-active app's status item is visible, then lets
/// the normal auto-rehide timer tuck things away again.
final class ActivityMonitor {

    /// Called when activity warrants a temporary reveal.
    var onActivity: (() -> Void)?

    private(set) var isRunning = false
    private var observer: NSObjectProtocol?

    func start() {
        guard !isRunning else { return }
        isRunning = true
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main) { [weak self] _ in
            self?.onActivity?()
        }
    }

    func stop() {
        guard isRunning, let observer else { return }
        NSWorkspace.shared.notificationCenter.removeObserver(observer)
        self.observer = nil
        isRunning = false
    }
}
