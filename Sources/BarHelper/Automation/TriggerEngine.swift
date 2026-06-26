import Foundation

/// Evaluates automation triggers (REQ-A01).
///
/// Condition evaluation is pure and takes an injected `Context`, so it is fully
/// unit-testable without touching hardware. `liveContext()` builds a real
/// snapshot from the system; conditions that have no reliable public API
/// (Focus mode, precise location) degrade to "not satisfied" rather than
/// guessing.
struct TriggerEngine {

    /// A snapshot of the system state a condition is evaluated against.
    struct Context: Equatable {
        var batteryPercent: Int?
        var isCharging: Bool
        var ssid: String?
        var date: Date
        var focusModeName: String?
        var locationName: String?
    }

    /// Returns the actions whose (enabled) triggers are currently satisfied.
    func firedActions(for triggers: [Trigger], in context: Context) -> [TriggerAction] {
        triggers
            .filter { $0.enabled && isSatisfied($0.condition, in: context) }
            .map { $0.action }
    }

    /// Pure condition test. Exposed for unit testing.
    func isSatisfied(_ condition: TriggerCondition, in ctx: Context) -> Bool {
        switch condition.kind {
        case .onBattery:
            return ctx.batteryPercent != nil && !ctx.isCharging
        case .charging:
            return ctx.isCharging
        case .batteryBelow:
            guard let threshold = condition.batteryThreshold,
                  let level = ctx.batteryPercent else { return false }
            return level < threshold
        case .wifiNetwork:
            guard let want = condition.ssid, let have = ctx.ssid else { return false }
            return want.caseInsensitiveCompare(have) == .orderedSame
        case .location:
            guard let want = condition.locationName, let have = ctx.locationName else { return false }
            return want.caseInsensitiveCompare(have) == .orderedSame
        case .schedule:
            guard let start = condition.scheduleStartHour,
                  let end = condition.scheduleEndHour else { return false }
            let hour = Calendar.current.component(.hour, from: ctx.date)
            // Support overnight ranges (e.g. 22 → 6).
            if start <= end {
                return hour >= start && hour < end
            } else {
                return hour >= start || hour < end
            }
        case .focusMode:
            guard let want = condition.focusModeName, let have = ctx.focusModeName else { return false }
            return want.caseInsensitiveCompare(have) == .orderedSame
        }
    }
}
