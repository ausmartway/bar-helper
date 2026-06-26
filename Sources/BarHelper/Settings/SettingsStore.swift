import Foundation
import Combine

/// Persists profiles and exposes the active one. Backed by `UserDefaults` with
/// `Codable` encoding (REQ-C09). This is the single source of truth shared
/// between the AppKit `MenuBarManager` and the SwiftUI settings views — both
/// observe `objectWillChange` so state never diverges.
final class SettingsStore: ObservableObject {

    private enum Key {
        static let profiles = "profiles"
        static let activeProfileID = "activeProfileID"
    }

    private let defaults: UserDefaults

    @Published private(set) var profiles: [Profile]
    @Published private(set) var activeProfileID: UUID

    /// Undo/redo history of profile snapshots (REQ-I03). Each entry is the full
    /// `profiles` array before a mutation, which keeps undo simple and correct
    /// across section moves, styling, and profile add/delete.
    private var undoStack: [[Profile]] = []
    private var redoStack: [[Profile]] = []
    private let maxHistory = 50

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let loaded = SettingsStore.loadProfiles(from: defaults)
        let profiles = loaded.isEmpty ? [Profile.default] : loaded
        self.profiles = profiles

        if let raw = defaults.string(forKey: Key.activeProfileID),
           let id = UUID(uuidString: raw),
           profiles.contains(where: { $0.id == id }) {
            self.activeProfileID = id
        } else {
            self.activeProfileID = profiles[0].id
        }
    }

    /// The currently active profile (REQ-I04: always valid, never nil).
    var profile: Profile {
        profiles.first(where: { $0.id == activeProfileID }) ?? profiles[0]
    }

    // MARK: - Mutation

    /// Replace the active profile and persist. The single write path keeps the
    /// store consistent and is where undo history is captured (REQ-I03).
    func update(_ transform: (inout Profile) -> Void) {
        guard let index = profiles.firstIndex(where: { $0.id == activeProfileID }) else { return }
        var copy = profiles[index]
        transform(&copy)
        guard copy != profiles[index] else { return } // no-op edits don't pollute history
        captureHistory()
        profiles[index] = copy
        persist()
    }

    func addProfile(named name: String) {
        captureHistory()
        var new = Profile.default
        new.name = name
        profiles.append(new)
        activeProfileID = new.id
        persist()
    }

    func switchTo(_ id: UUID) {
        guard profiles.contains(where: { $0.id == id }) else { return }
        activeProfileID = id
        persist()
    }

    /// Switch by profile name (used by triggers and the URL scheme). No-op if
    /// no profile matches.
    func switchTo(named name: String) {
        guard let match = profiles.first(where: {
            $0.name.caseInsensitiveCompare(name) == .orderedSame
        }) else { return }
        switchTo(match.id)
    }

    func deleteProfile(_ id: UUID) {
        guard profiles.count > 1 else { return } // always keep one
        captureHistory()
        profiles.removeAll { $0.id == id }
        if activeProfileID == id { activeProfileID = profiles[0].id }
        persist()
    }

    // MARK: - Undo / redo (REQ-I03)

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(profiles)
        restore(previous)
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(profiles)
        restore(next)
    }

    private func captureHistory() {
        undoStack.append(profiles)
        if undoStack.count > maxHistory { undoStack.removeFirst() }
        redoStack.removeAll() // a fresh edit invalidates the redo branch
    }

    private func restore(_ snapshot: [Profile]) {
        profiles = snapshot
        if !profiles.contains(where: { $0.id == activeProfileID }) {
            activeProfileID = profiles[0].id
        }
        persist()
    }

    // MARK: - Persistence

    private func persist() {
        if let data = try? JSONEncoder().encode(profiles) {
            defaults.set(data, forKey: Key.profiles)
        }
        defaults.set(activeProfileID.uuidString, forKey: Key.activeProfileID)
    }

    private static func loadProfiles(from defaults: UserDefaults) -> [Profile] {
        guard let data = defaults.data(forKey: Key.profiles),
              let decoded = try? JSONDecoder().decode([Profile].self, from: data)
        else { return [] }
        return decoded
    }
}
