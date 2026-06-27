import XCTest
@testable import BarHelper

/// Tests for the automation/trigger layer (REQ-A01/A03) and the extended model.
final class AutomationTests: XCTestCase {

    private let engine = TriggerEngine()

    private func context(battery: Int? = nil, charging: Bool = false,
                         ssid: String? = nil, hour: Int = 12,
                         focus: String? = nil, location: String? = nil) -> TriggerEngine.Context {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 6; comps.day = 26; comps.hour = hour
        let date = Calendar.current.date(from: comps)!
        return TriggerEngine.Context(batteryPercent: battery, isCharging: charging,
                                     ssid: ssid, date: date, focusModeName: focus, locationName: location)
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

    func testScheduleBoundariesAreHalfOpenAndRequireBothHours() {
        let work = TriggerCondition(kind: .schedule, scheduleStartHour: 9, scheduleEndHour: 17)
        XCTAssertTrue(engine.isSatisfied(work, in: context(hour: 9)))   // inclusive start
        XCTAssertFalse(engine.isSatisfied(work, in: context(hour: 17))) // exclusive end
        // Missing hours never fire.
        let incomplete = TriggerCondition(kind: .schedule, scheduleStartHour: 9)
        XCTAssertFalse(engine.isSatisfied(incomplete, in: context(hour: 12)))
    }

    func testBatteryBelowIsStrictAndNeedsThreshold() {
        let cond = TriggerCondition(kind: .batteryBelow, batteryThreshold: 20)
        XCTAssertFalse(engine.isSatisfied(cond, in: context(battery: 20))) // strict <
        let noThreshold = TriggerCondition(kind: .batteryBelow)
        XCTAssertFalse(engine.isSatisfied(noThreshold, in: context(battery: 5)))
    }

    func testLocationConditionMatchesCaseInsensitively() {
        let cond = TriggerCondition(kind: .location, locationName: "Home")
        XCTAssertTrue(engine.isSatisfied(cond, in: context(location: "home")))
        XCTAssertFalse(engine.isSatisfied(cond, in: context(location: "Office")))
        XCTAssertFalse(engine.isSatisfied(cond, in: context(location: nil)))
    }

    func testFocusModeConditionMatchesCaseInsensitively() {
        let cond = TriggerCondition(kind: .focusMode, focusModeName: "Work")
        XCTAssertTrue(engine.isSatisfied(cond, in: context(focus: "work")))
        XCTAssertFalse(engine.isSatisfied(cond, in: context(focus: "Sleep")))
        XCTAssertFalse(engine.isSatisfied(cond, in: context(focus: nil)))
    }

    func testFiredTriggersRespectEnabledFlagAndOrder() {
        let cond = TriggerCondition(kind: .charging)
        let on = Trigger(name: "A", enabled: true, condition: cond, action: TriggerAction(kind: .hideItems))
        let off = Trigger(name: "B", enabled: false, condition: cond, action: TriggerAction(kind: .showItems))
        let also = Trigger(name: "C", enabled: true, condition: cond, action: TriggerAction(kind: .showItems))
        let fired = engine.firedTriggers(for: [on, off, also], in: context(charging: true))
        // Disabled trigger excluded; order preserved.
        XCTAssertEqual(fired.map(\.name), ["A", "C"])
        XCTAssertEqual(fired.first?.action.kind, .hideItems)
        // Empty input → empty output.
        XCTAssertTrue(engine.firedTriggers(for: [], in: context(charging: true)).isEmpty)
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

    func testURLSchemeFallbacksAndMalformedInput() {
        var revealed: MenuBarSection?
        var toggled: MenuBarSection?
        var switchedTo: String?
        var hideCount = 0
        let handler = URLSchemeHandler(commands: URLSchemeHandler.Commands(
            reveal: { revealed = $0 },
            hide: { hideCount += 1 },
            toggle: { toggled = $0 },
            switchProfile: { switchedTo = $0 }
        ))

        // Missing section defaults to .hidden for show and toggle.
        handler.dispatch(URL(string: "barhelper://show")!)
        XCTAssertEqual(revealed, .hidden)
        handler.dispatch(URL(string: "barhelper://toggle")!)
        XCTAssertEqual(toggled, .hidden)

        // Invalid section value falls back to .hidden, not a crash.
        revealed = nil
        handler.dispatch(URL(string: "barhelper://show?section=bogus")!)
        XCTAssertEqual(revealed, .hidden)

        // profile without a name does nothing.
        handler.dispatch(URL(string: "barhelper://profile")!)
        XCTAssertNil(switchedTo)

        // Unknown host fires no command.
        handler.dispatch(URL(string: "barhelper://frobnicate")!)
        XCTAssertEqual(hideCount, 0)
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
