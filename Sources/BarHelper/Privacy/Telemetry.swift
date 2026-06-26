import Foundation

/// REQ-B01: bar-helper collects **no** analytics or telemetry, ever. Privacy is
/// a first-class, non-configurable guarantee — this is the lesson learned from
/// Bartender's silent 2024 addition of analytics that triggered a mass exodus.
///
/// This type exists precisely so there is one obvious place that proves the
/// absence of telemetry. It has no network code and never will. Any future
/// reviewer searching for "analytics" or "telemetry" should land here and find
/// nothing but this assertion.
enum Telemetry {
    /// Called once at launch. Intentionally a no-op: there is nothing to
    /// initialize because there is nothing to report.
    static func assertDisabled() {
        // No SDKs. No endpoints. No identifiers. No-op by design.
    }
}
