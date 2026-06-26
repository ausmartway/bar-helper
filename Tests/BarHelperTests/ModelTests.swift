import XCTest
@testable import BarHelper

/// Unit tests for the portable model layer. These exercise the parts of
/// bar-helper that don't require a live menu bar, so they run headlessly in CI.
final class ModelTests: XCTestCase {

    /// A profile must round-trip through Codable so saved layouts and profile
    /// switching (REQ-C09 / REQ-I04) are reliable.
    func testProfileCodableRoundTrip() throws {
        var profile = Profile.default
        profile.name = "Work"
        profile.sectionAssignments["com.example.app|Clock"] = .alwaysHidden
        profile.reveal.autoRehideDelay = 12
        profile.appearance.tint = RGBAColor(red: 0.2, green: 0.3, blue: 0.4, alpha: 0.8)

        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(Profile.self, from: data)

        XCTAssertEqual(decoded, profile)
    }

    /// Items not explicitly assigned default to the visible section (REQ-C01).
    func testUnassignedItemDefaultsToVisible() {
        let profile = Profile.default
        XCTAssertEqual(profile.section(for: "anything"), .visible)
    }

    func testAssignedItemReportsItsSection() {
        var profile = Profile.default
        profile.sectionAssignments["x|y"] = .hidden
        XCTAssertEqual(profile.section(for: "x|y"), .hidden)
    }

    /// The store always exposes a valid active profile and never loses the last
    /// one (REQ-I04: complete, robust profiles).
    func testStoreAlwaysHasActiveProfile() {
        let defaults = UserDefaults(suiteName: "bar-helper.tests.\(UUID().uuidString)")!
        let store = SettingsStore(defaults: defaults)

        XCTAssertFalse(store.profiles.isEmpty)
        XCTAssertEqual(store.profile.id, store.activeProfileID)

        // Deleting down to the last profile is a no-op (must keep one).
        for profile in store.profiles {
            store.deleteProfile(profile.id)
        }
        XCTAssertEqual(store.profiles.count, 1)
    }

    /// Undo/redo must reverse and replay configuration edits (REQ-I03).
    func testUndoRedoRoundTrip() {
        let defaults = UserDefaults(suiteName: "bar-helper.tests.\(UUID().uuidString)")!
        let store = SettingsStore(defaults: defaults)

        XCTAssertFalse(store.canUndo)
        store.update { $0.reveal.autoRehideDelay = 20 }
        XCTAssertEqual(store.profile.reveal.autoRehideDelay, 20)
        XCTAssertTrue(store.canUndo)

        store.undo()
        XCTAssertEqual(store.profile.reveal.autoRehideDelay, RevealSettings.default.autoRehideDelay)
        XCTAssertTrue(store.canRedo)

        store.redo()
        XCTAssertEqual(store.profile.reveal.autoRehideDelay, 20)
    }

    /// No-op edits must not create undo history (REQ-I03 quality).
    func testNoOpEditDoesNotRecordHistory() {
        let defaults = UserDefaults(suiteName: "bar-helper.tests.\(UUID().uuidString)")!
        let store = SettingsStore(defaults: defaults)
        let current = store.profile.reveal.autoRehideDelay
        store.update { $0.reveal.autoRehideDelay = current } // unchanged
        XCTAssertFalse(store.canUndo)
    }

    /// All three sections are representable and stable (REQ-C01).
    func testSectionsAreExhaustive() {
        XCTAssertEqual(MenuBarSection.allCases.count, 3)
        XCTAssertEqual(MenuBarSection.separatorSections, [.hidden, .alwaysHidden])
    }
}
