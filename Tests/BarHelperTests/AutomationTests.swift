import XCTest
@testable import BarHelper

/// Tests for the automation/trigger layer (REQ-A01/A03) and the extended model.
final class AutomationTests: XCTestCase {

    private let engine = TriggerEngine()

    private func context(battery: Int? = nil, charging: Bool = false,
                         ssid: String? = nil, hour: Int = 12) -> TriggerEngine.Context {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 6; comps.day = 26; comps.hour = hour
        let date = Calendar.current.date(from: comps)!
        return TriggerEngine.Context(batteryPercent: battery, isCharging: charging,
                                     ssid: ssid, date: date, focusModeName: nil, locationName: nil)
    }

    // MARK: - Trigger conditions (REQ-A01)

    func testBatteryBelowFires() {
        let cond = TriggerCondition(kind: .batteryBelow, batteryThreshold: 20)
        XCTAssertTrue(engine.isSatisfied(cond, in: context(battery: 15)))
        XCTAssertFalse(engine.isSatisfied(cond, in: context(battery: 50)))
        XCTAssertFalse(engine.isSatisfied(cond, in: context(battery: nil)))
    }

    func testOnBatteryAndCharging() {
        let onBattery = TriggerCondition(kind: .onBattery)
        let charging = TriggerCondition(kind: .charging)
        XCTAssertTrue(engine.isSatisfied(onBattery, in: context(battery: 80, charging: false)))
        XCTAssertFalse(engine.isSatisfied(onBattery, in: context(battery: 80, charging: true)))
        XCTAssertTrue(engine.isSatisfied(charging, in: context(charging: true)))
    }

    func testWifiNetworkMatchIsCaseInsensitive() {
        let cond = TriggerCondition(kind: .wifiNetwork, ssid: "HomeNet")
        XCTAssertTrue(engine.isSatisfied(cond, in: context(ssid: "homenet")))
        XCTAssertFalse(engine.isSatisfied(cond, in: context(ssid: "Office")))
    }

    func testScheduleHandlesNormalAndOvernightRanges() {
        let workHours = TriggerCondition(kind: .schedule, scheduleStartHour: 9, scheduleEndHour: 17)
        XCTAssertTrue(engine.isSatisfied(workHours, in: context(hour: 12)))
        XCTAssertFalse(engine.isSatisfied(workHours, in: context(hour: 20)))

        let overnight = TriggerCondition(kind: .schedule, scheduleStartHour: 22, scheduleEndHour: 6)
        XCTAssertTrue(engine.isSatisfied(overnight, in: context(hour: 23)))
        XCTAssertTrue(engine.isSatisfied(overnight, in: context(hour: 3)))
        XCTAssertFalse(engine.isSatisfied(overnight, in: context(hour: 12)))
    }

    func testFiredActionsRespectEnabledFlag() {
        let cond = TriggerCondition(kind: .charging)
        let on = Trigger(name: "A", enabled: true, condition: cond, action: TriggerAction(kind: .hideItems))
        let off = Trigger(name: "B", enabled: false, condition: cond, action: TriggerAction(kind: .showItems))
        let fired = engine.firedActions(for: [on, off], in: context(charging: true))
        XCTAssertEqual(fired.count, 1)
        XCTAssertEqual(fired.first?.kind, .hideItems)
    }

    // MARK: - URL scheme (REQ-A03)

    func testURLSchemeDispatch() {
        var revealed: MenuBarSection?
        var toggled: MenuBarSection?
        var hidden = false
        var switchedTo: String?
        let handler = URLSchemeHandler(commands: URLSchemeHandler.Commands(
            reveal: { revealed = $0 },
            hide: { hidden = true },
            toggle: { toggled = $0 },
            switchProfile: { switchedTo = $0 }
        ))

        handler.dispatch(URL(string: "barhelper://show?section=alwaysHidden")!)
        XCTAssertEqual(revealed, .alwaysHidden)

        handler.dispatch(URL(string: "barhelper://toggle?section=hidden")!)
        XCTAssertEqual(toggled, .hidden)

        handler.dispatch(URL(string: "barhelper://hide")!)
        XCTAssertTrue(hidden)

        handler.dispatch(URL(string: "barhelper://profile?name=Work")!)
        XCTAssertEqual(switchedTo, "Work")

        // Wrong scheme is ignored.
        switchedTo = nil
        handler.dispatch(URL(string: "https://example.com/profile?name=X")!)
        XCTAssertNil(switchedTo)
    }

    // MARK: - Extended model (REQ-C12..C21)

    func testExtendedProfileCodableRoundTrip() throws {
        var profile = Profile.default
        profile.layout.itemSpacing = 4
        profile.layout.defaultSectionForNewItems = .hidden
        profile.spacers = [MenuBarSpacer(label: "🎵", section: .hidden)]
        profile.groups = [ItemGroup(name: "Media", itemIDs: ["a", "b"])]
        profile.itemHotkeys = [ItemHotkey(itemID: "x", keyCode: 1, modifiers: 2, temporaryReveal: true)]
        profile.triggers = [Trigger(name: "Low batt",
                                    condition: TriggerCondition(kind: .batteryBelow, batteryThreshold: 10),
                                    action: TriggerAction(kind: .showItems, itemIDs: ["bat"]))]
        profile.hideOverlappingAppMenus = true
        profile.darkAppearance = .default
        profile.appearance.separatorIconSymbol = "ellipsis"

        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(Profile.self, from: data)
        XCTAssertEqual(decoded, profile)
    }

    func testLayoutDefaults() {
        let layout = LayoutSettings.default
        XCTAssertEqual(layout.defaultSectionForNewItems, .visible)
        XCTAssertEqual(layout.itemSpacing, 16)
    }

    func testExpandedHotkeyActionsPresent() {
        XCTAssertTrue(HotkeyAction.allCases.contains(.toggleAppMenus))
        XCTAssertTrue(HotkeyAction.allCases.contains(.toggleSecondaryBar))
        XCTAssertTrue(HotkeyAction.allCases.contains(.toggleSeparatorIcons))
        XCTAssertTrue(HotkeyAction.allCases.contains(.toggleAutoRehide))
    }

    func testDarkAppearanceSelection() {
        var profile = Profile.default
        XCTAssertEqual(profile.appearance(forDarkMode: true), profile.appearance)
        var dark = Appearance.default
        dark.tint = RGBAColor(white: 0, alpha: 1)
        profile.darkAppearance = dark
        XCTAssertEqual(profile.appearance(forDarkMode: true), dark)
        XCTAssertEqual(profile.appearance(forDarkMode: false), profile.appearance)
    }
}
