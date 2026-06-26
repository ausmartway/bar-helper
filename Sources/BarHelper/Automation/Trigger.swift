import Foundation

/// A condition → action automation rule (REQ-A01). Modeled as plain structs
/// with a `kind` enum plus parameter fields (rather than enums with associated
/// values) so the whole thing round-trips through synthesized `Codable`.
struct Trigger: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var enabled: Bool
    var condition: TriggerCondition
    var action: TriggerAction

    init(id: UUID = UUID(),
         name: String,
         enabled: Bool = true,
         condition: TriggerCondition,
         action: TriggerAction) {
        self.id = id
        self.name = name
        self.enabled = enabled
        self.condition = condition
        self.action = action
    }
}

/// When a trigger fires.
struct TriggerCondition: Codable, Equatable {
    enum Kind: String, Codable, CaseIterable, Identifiable {
        case onBattery          // running on battery power
        case charging           // connected to power
        case batteryBelow       // battery percentage below `batteryThreshold`
        case wifiNetwork        // connected to SSID `ssid`
        case location           // near a saved location (best effort)
        case schedule           // current hour within [startHour, endHour)
        case focusMode          // a macOS Focus mode named `focusModeName` is on

        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .onBattery: return "On battery"
            case .charging: return "Charging"
            case .batteryBelow: return "Battery below %"
            case .wifiNetwork: return "Wi-Fi network"
            case .location: return "Location"
            case .schedule: return "Schedule"
            case .focusMode: return "Focus mode"
            }
        }
    }

    var kind: Kind
    var batteryThreshold: Int?
    var ssid: String?
    var scheduleStartHour: Int?
    var scheduleEndHour: Int?
    var focusModeName: String?
    var locationName: String?

    init(kind: Kind,
         batteryThreshold: Int? = nil,
         ssid: String? = nil,
         scheduleStartHour: Int? = nil,
         scheduleEndHour: Int? = nil,
         focusModeName: String? = nil,
         locationName: String? = nil) {
        self.kind = kind
        self.batteryThreshold = batteryThreshold
        self.ssid = ssid
        self.scheduleStartHour = scheduleStartHour
        self.scheduleEndHour = scheduleEndHour
        self.focusModeName = focusModeName
        self.locationName = locationName
    }
}

/// What a trigger does when its condition is satisfied.
struct TriggerAction: Codable, Equatable {
    enum Kind: String, Codable, CaseIterable, Identifiable {
        case showItems
        case hideItems
        case switchProfile

        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .showItems: return "Show items"
            case .hideItems: return "Hide items"
            case .switchProfile: return "Switch profile"
            }
        }
    }

    var kind: Kind
    var itemIDs: [String]
    var profileName: String?

    init(kind: Kind, itemIDs: [String] = [], profileName: String? = nil) {
        self.kind = kind
        self.itemIDs = itemIDs
        self.profileName = profileName
    }
}

/// Automation surface toggles (REQ-A02 / REQ-A03).
struct AutomationSettings: Codable, Equatable {
    /// Briefly reveal a hidden item when its icon updates/changes (REQ-A02).
    var temporaryRevealOnActivity: Bool
    /// Allow control via the `barhelper://` URL scheme, which AppleScript and
    /// the Shortcuts app can drive (REQ-A03).
    var urlSchemeEnabled: Bool

    static var `default`: AutomationSettings {
        AutomationSettings(temporaryRevealOnActivity: true, urlSchemeEnabled: true)
    }
}
