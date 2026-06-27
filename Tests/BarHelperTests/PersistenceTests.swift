import XCTest
@testable import BarHelper

/// Tests for persistence and back-compatible decoding (REQ-C09/I04) — the
/// areas a review flagged as able to silently lose user data.
final class PersistenceTests: XCTestCase {

    /// A profile JSON written by an older build (only the v1 keys, and an
    /// Appearance with only its v1 fields) must still decode, with the
    /// post-v1 fields falling back to their defaults rather than throwing.
    func testDecodesLegacyProfileJSONWithDefaults() throws {
        let legacy = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "name": "Legacy",
          "sectionAssignments": { "com.example|Clock": "hidden" },
          "reveal": { "onClick": true, "onHover": false, "onScroll": true, "autoRehideDelay": 6 },
          "appearance": {
            "hasBorder": false,
            "borderColor": { "red": 0, "green": 0, "blue": 0, "alpha": 0.25 },
            "hasShadow": true,
            "cornerRadius": 0
          },
          "hotkeys": [],
          "launchAtLogin": false
        }
        """.data(using: .utf8)!

        let profile = try JSONDecoder().decode(Profile.self, from: legacy)

        // v1 fields preserved.
        XCTAssertEqual(profile.name, "Legacy")
        XCTAssertEqual(profile.section(for: "com.example|Clock"), .hidden)
        // New fields defaulted, not thrown.
        XCTAssertEqual(profile.layout, .default)
        XCTAssertEqual(profile.automation, .default)
        XCTAssertTrue(profile.spacers.isEmpty)
        XCTAssertTrue(profile.triggers.isEmpty)
        XCTAssertFalse(profile.hideOverlappingAppMenus)
        XCTAssertNil(profile.darkAppearance)
        // Appearance's new styling fields defaulted too.
        XCTAssertEqual(profile.appearance.separatorIconSymbol, "chevron.left")
        XCTAssertTrue(profile.appearance.showDividerIcons)
    }

    /// Profiles must survive a persist → reload across two store instances on
    /// the same UserDefaults suite (the heart of REQ-C09).
    func testPersistenceRoundTripAcrossStoreInstances() {
        let suite = "bar-helper.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!

        let store = SettingsStore(defaults: defaults)
        store.addProfile(named: "Work")
        store.update { $0.layout.itemSpacing = 3 }
        let activeID = store.activeProfileID

        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertTrue(reloaded.profiles.contains { $0.name == "Work" })
        XCTAssertEqual(reloaded.activeProfileID, activeID)
        XCTAssertEqual(reloaded.profile.layout.itemSpacing, 3)
    }

    func testDeleteActiveProfileReassignsActive() {
        let defaults = UserDefaults(suiteName: "bar-helper.tests.\(UUID().uuidString)")!
        let store = SettingsStore(defaults: defaults)
        store.addProfile(named: "Second")
        let secondID = store.activeProfileID

        store.deleteProfile(secondID)
        XCTAssertFalse(store.profiles.contains { $0.id == secondID })
        XCTAssertEqual(store.activeProfileID, store.profiles[0].id)
        XCTAssertNotNil(store.profiles.first { $0.id == store.activeProfileID })
    }

    func testDeleteNonActiveProfileKeepsActive() {
        let defaults = UserDefaults(suiteName: "bar-helper.tests.\(UUID().uuidString)")!
        let store = SettingsStore(defaults: defaults)
        let original = store.activeProfileID
        store.addProfile(named: "Other")   // becomes active
        store.switchTo(original)           // back to first
        let otherID = store.profiles.first { $0.name == "Other" }!.id

        store.deleteProfile(otherID)
        XCTAssertEqual(store.activeProfileID, original)
    }

    func testSwitchToNamedIsCaseInsensitiveAndNoOpOnMiss() {
        let defaults = UserDefaults(suiteName: "bar-helper.tests.\(UUID().uuidString)")!
        let store = SettingsStore(defaults: defaults)
        store.addProfile(named: "Work")
        let workID = store.activeProfileID
        store.switchTo(store.profiles[0].id) // back to Default

        store.switchTo(named: "work")        // case-insensitive
        XCTAssertEqual(store.activeProfileID, workID)

        store.switchTo(named: "Nonexistent") // no-op
        XCTAssertEqual(store.activeProfileID, workID)
    }

    // MARK: - Undo/redo edges (REQ-I03)

    func testRedoStackClearedByNewEdit() {
        let defaults = UserDefaults(suiteName: "bar-helper.tests.\(UUID().uuidString)")!
        let store = SettingsStore(defaults: defaults)
        store.update { $0.reveal.autoRehideDelay = 10 }
        store.undo()
        XCTAssertTrue(store.canRedo)
        store.update { $0.reveal.autoRehideDelay = 99 } // fresh edit invalidates redo
        XCTAssertFalse(store.canRedo)
    }

    func testNonHistoryUpdateDoesNotRecordUndo() {
        let defaults = UserDefaults(suiteName: "bar-helper.tests.\(UUID().uuidString)")!
        let store = SettingsStore(defaults: defaults)
        store.update(recordHistory: false) { $0.reveal.autoRehideDelay = 20 }
        XCTAssertEqual(store.profile.reveal.autoRehideDelay, 20) // change applied
        XCTAssertFalse(store.canUndo)                            // but not in history
    }
}
