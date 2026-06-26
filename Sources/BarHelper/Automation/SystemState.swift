import Foundation
import IOKit.ps
import CoreWLAN

/// Builds a live `TriggerEngine.Context` from the system. Isolated from the
/// pure evaluation logic so triggers stay unit-testable.
enum SystemState {

    static func liveContext() -> TriggerEngine.Context {
        let battery = batteryInfo()
        return TriggerEngine.Context(
            batteryPercent: battery.percent,
            isCharging: battery.charging,
            ssid: currentSSID(),
            date: Date(),
            // No reliable public API for these; left nil so dependent triggers
            // simply don't fire rather than firing on a guess.
            focusModeName: nil,
            locationName: nil
        )
    }

    /// Current battery percentage and whether the Mac is on AC power. Returns
    /// `(nil, false)` on desktops with no battery.
    static func batteryInfo() -> (percent: Int?, charging: Bool) {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef]
        else { return (nil, false) }

        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(blob, source)?
                .takeUnretainedValue() as? [String: Any] else { continue }
            let state = desc[kIOPSPowerSourceStateKey] as? String
            let charging = (state == kIOPSACPowerValue)
            if let capacity = desc[kIOPSCurrentCapacityKey] as? Int,
               let maximum = desc[kIOPSMaxCapacityKey] as? Int, maximum > 0 {
                return (Int(Double(capacity) / Double(maximum) * 100.0), charging)
            }
        }
        return (nil, false)
    }

    /// Current Wi-Fi SSID, if available. May be nil without Location access on
    /// recent macOS — callers treat nil as "unknown", not an error.
    static func currentSSID() -> String? {
        CWWiFiClient.shared().interface()?.ssid()
    }
}
