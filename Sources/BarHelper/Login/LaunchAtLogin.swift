import Foundation
import ServiceManagement

/// Launch-at-login via the modern `SMAppService` API (REQ-C08).
///
/// `SMAppService.mainApp` registers the running app bundle as a login item.
/// Registration only succeeds for a properly bundled, signed `.app`; from a
/// bare command-line build it returns an error, which is logged rather than
/// surfaced as a crash — keeping development builds usable.
final class LaunchAtLogin {

    static let shared = LaunchAtLogin()

    private init() {}

    /// Current registration state, best-effort.
    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Bring the login-item registration in line with the user's preference.
    func synchronize(enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            // Expected when run as an unbundled binary; not fatal.
            NSLog("bar-helper: launch-at-login update skipped: \(error.localizedDescription)")
        }
    }
}
