import Foundation

/// Applies menu-bar item spacing (REQ-C12).
///
/// macOS exposes two undocumented-but-stable global defaults that control the
/// gap and click padding around every status item: `NSStatusItemSpacing` and
/// `NSStatusItemSelectionPadding`. They live in the global domain for the
/// current host (equivalent to
/// `defaults -currentHost write -globalDomain NSStatusItemSpacing -int N`).
/// Changes take effect after the menu bar (or session) restarts.
enum SpacingManager {

    private static let spacingKey = "NSStatusItemSpacing" as CFString
    private static let paddingKey = "NSStatusItemSelectionPadding" as CFString
    private static let domain = kCFPreferencesAnyApplication

    /// Write the spacing/padding to the global current-host domain.
    static func apply(spacing: Int) {
        let value = NSNumber(value: max(0, spacing))
        CFPreferencesSetValue(spacingKey, value, domain,
                              kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
        CFPreferencesSetValue(paddingKey, value, domain,
                              kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
        CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
    }

    /// Remove the overrides, restoring the system default spacing.
    static func reset() {
        CFPreferencesSetValue(spacingKey, nil, domain,
                              kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
        CFPreferencesSetValue(paddingKey, nil, domain,
                              kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
        CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
    }
}
