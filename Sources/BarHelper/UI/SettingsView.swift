import SwiftUI
import AppKit
import Carbon.HIToolbox

/// The settings window. One tab per area of the spec. All edits flow through
/// `SettingsStore.update`, the single write path, so the AppKit menu-bar
/// controller and this UI never diverge.
struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var permissions: PermissionsManager
    let onShowHiddenPanel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // REQ-I03: undo/redo available across all configuration edits.
            HStack {
                Button {
                    settings.undo()
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .disabled(!settings.canUndo)

                Button {
                    settings.redo()
                } label: {
                    Label("Redo", systemImage: "arrow.uturn.forward")
                }
                .disabled(!settings.canRedo)

                Spacer()
                Text("Profile: \(settings.profile.name)")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            paneTabs
        }
        .frame(width: 640, height: 520)
    }

    private var paneTabs: some View {
        TabView {
            GeneralPane(settings: settings, onShowHiddenPanel: onShowHiddenPanel)
                .tabItem { Label("General", systemImage: "gearshape") }

            SectionsPane(settings: settings)
                .tabItem { Label("Sections", systemImage: "rectangle.split.3x1") }

            AppearancePane(settings: settings)
                .tabItem { Label("Appearance", systemImage: "paintbrush") }

            HotkeysPane(settings: settings)
                .tabItem { Label("Hotkeys", systemImage: "command") }

            ProfilesPane(settings: settings)
                .tabItem { Label("Profiles", systemImage: "person.crop.rectangle.stack") }

            PermissionsPane(permissions: permissions)
                .tabItem { Label("Permissions", systemImage: "lock.shield") }
        }
        .frame(width: 640, height: 520)
    }
}

// MARK: - General (REQ-C02/C03/C08/C10)

private struct GeneralPane: View {
    @ObservedObject var settings: SettingsStore
    let onShowHiddenPanel: () -> Void

    var body: some View {
        Form {
            Section("Reveal hidden items") {
                Toggle("On click in the menu bar", isOn: bind(\.reveal.onClick))
                Toggle("On hover", isOn: bind(\.reveal.onHover))
                Toggle("On scroll / swipe", isOn: bind(\.reveal.onScroll))
            }

            Section("Auto-rehide") {
                let delay = settings.profile.reveal.autoRehideDelay
                Slider(value: bind(\.reveal.autoRehideDelay), in: 0...30, step: 1) {
                    Text("Delay")
                } minimumValueLabel: {
                    Text("Off")
                } maximumValueLabel: {
                    Text("30s")
                }
                Text(delay == 0 ? "Auto-rehide disabled" : "Re-hide after \(Int(delay))s of inactivity")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Startup") {
                Toggle("Launch bar-helper at login", isOn: Binding(
                    get: { settings.profile.launchAtLogin },
                    set: { newValue in
                        settings.update { $0.launchAtLogin = newValue }
                        LaunchAtLogin.shared.synchronize(enabled: newValue)
                    }
                ))
            }

            Section("Hidden items bar") {
                Button("Show hidden items bar", action: onShowHiddenPanel)
                Text("An alternative to expanding the menu bar — lists hidden items in a strip.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func bind<Value>(_ keyPath: WritableKeyPath<Profile, Value>) -> Binding<Value> {
        Binding(
            get: { settings.profile[keyPath: keyPath] },
            set: { newValue in settings.update { $0[keyPath: keyPath] = newValue } }
        )
    }
}

// MARK: - Sections + search (REQ-C04 / REQ-C06)

private struct SectionsPane: View {
    @ObservedObject var settings: SettingsStore
    @State private var search = ""
    @State private var newItemName = ""

    private var assignments: [(item: String, section: MenuBarSection)] {
        settings.profile.sectionAssignments
            .map { (item: $0.key, section: $0.value) }
            .filter { search.isEmpty || $0.item.localizedCaseInsensitiveContains(search) }
            .sorted { $0.item < $1.item }
    }

    var body: some View {
        VStack(alignment: .leading) {
            // REQ-C06: search hidden/assigned items.
            TextField("Search menu bar items", text: $search)
                .textFieldStyle(.roundedBorder)
                .padding(.bottom, 4)

            List {
                ForEach(assignments, id: \.item) { entry in
                    HStack {
                        Text(entry.item)
                        Spacer()
                        // REQ-C04: move an item between sections.
                        Picker("", selection: Binding(
                            get: { entry.section },
                            set: { newSection in
                                settings.update { $0.sectionAssignments[entry.item] = newSection }
                            }
                        )) {
                            ForEach(MenuBarSection.allCases) { section in
                                Text(section.displayName).tag(section)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 160)
                    }
                }
            }

            HStack {
                TextField("Add item identifier (bundle id or title)", text: $newItemName)
                    .textFieldStyle(.roundedBorder)
                Button("Add") {
                    let trimmed = newItemName.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    settings.update { $0.sectionAssignments[trimmed] = .hidden }
                    newItemName = ""
                }
                .disabled(newItemName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
    }
}

// MARK: - Appearance (REQ-C05)

private struct AppearancePane: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        Form {
            Section("Tint") {
                Toggle("Tint the menu bar", isOn: Binding(
                    get: { settings.profile.appearance.tint != nil },
                    set: { on in
                        settings.update {
                            $0.appearance.tint = on ? RGBAColor(red: 0.1, green: 0.1, blue: 0.2, alpha: 0.6) : nil
                        }
                    }
                ))
                if let tint = settings.profile.appearance.tint {
                    ColorPicker("Tint color", selection: Binding(
                        get: { Color(tint.nsColor) },
                        set: { newColor in
                            settings.update { $0.appearance.tint = newColor.rgba }
                        }
                    ))
                }
            }

            Section("Border") {
                Toggle("Show border", isOn: bind(\.appearance.hasBorder))
                ColorPicker("Border color", selection: Binding(
                    get: { Color(settings.profile.appearance.borderColor.nsColor) },
                    set: { newColor in
                        settings.update { $0.appearance.borderColor = newColor.rgba }
                    }
                ))
                .disabled(!settings.profile.appearance.hasBorder)
            }

            Section("Shape") {
                Toggle("Drop shadow", isOn: bind(\.appearance.hasShadow))
                Slider(value: bind(\.appearance.cornerRadius), in: 0...12, step: 1) {
                    Text("Corner radius")
                }
                Text("Corner radius: \(Int(settings.profile.appearance.cornerRadius))pt")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func bind<Value>(_ keyPath: WritableKeyPath<Profile, Value>) -> Binding<Value> {
        Binding(
            get: { settings.profile[keyPath: keyPath] },
            set: { newValue in settings.update { $0[keyPath: keyPath] = newValue } }
        )
    }
}

// MARK: - Hotkeys (REQ-C07)

private struct HotkeysPane: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading) {
            Text("Global hotkeys")
                .font(.headline)
            Text("Bindings take effect on next launch.")
                .font(.caption)
                .foregroundStyle(.secondary)
            List {
                ForEach(settings.profile.hotkeys) { binding in
                    HStack {
                        Text(binding.action.displayName)
                        Spacer()
                        Text(HotkeyFormatter.string(for: binding))
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Profiles (REQ-C09 / REQ-I04)

private struct ProfilesPane: View {
    @ObservedObject var settings: SettingsStore
    @State private var newProfileName = ""

    var body: some View {
        VStack(alignment: .leading) {
            Text("Profiles")
                .font(.headline)

            List {
                ForEach(settings.profiles) { profile in
                    HStack {
                        Image(systemName: profile.id == settings.activeProfileID
                              ? "largecircle.fill.circle" : "circle")
                        Text(profile.name)
                        Spacer()
                        if settings.profiles.count > 1 {
                            Button(role: .destructive) {
                                settings.deleteProfile(profile.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { settings.switchTo(profile.id) }
                }
            }

            HStack {
                TextField("New profile name", text: $newProfileName)
                    .textFieldStyle(.roundedBorder)
                Button("Add profile") {
                    let trimmed = newProfileName.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    settings.addProfile(named: trimmed)
                    newProfileName = ""
                }
                .disabled(newProfileName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
    }
}

// MARK: - Permissions (REQ-I05 / REQ-X02)

private struct PermissionsPane: View {
    @ObservedObject var permissions: PermissionsManager

    var body: some View {
        Form {
            Section("Screen Recording") {
                permissionRow(
                    granted: permissions.hasScreenRecording,
                    explanation: "Used to read the menu-bar layout and apply styling. bar-helper does not record your screen.",
                    request: { permissions.requestScreenRecording() },
                    openSettings: { permissions.openSystemSettings(for: .screenRecording) }
                )
            }

            Section("Accessibility") {
                permissionRow(
                    granted: permissions.hasAccessibility,
                    explanation: "Used to move and interact with menu-bar items.",
                    request: { permissions.requestAccessibility() },
                    openSettings: { permissions.openSystemSettings(for: .accessibility) }
                )
            }

            if !permissions.isFullyEnabled {
                Section {
                    Label("bar-helper runs in a limited mode until both permissions are granted.",
                          systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear { permissions.refresh() }
    }

    @ViewBuilder
    private func permissionRow(granted: Bool,
                               explanation: String,
                               request: @escaping () -> Void,
                               openSettings: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(granted ? Color.green : Color.secondary)
            Text(granted ? "Granted" : "Not granted")
            Spacer()
            if !granted {
                Button("Request", action: request)
            }
            Button("Open System Settings", action: openSettings)
        }
        Text(explanation)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

// MARK: - Helpers

/// Renders a Carbon-flagged hotkey as a readable string (e.g. "⌘⌥B").
enum HotkeyFormatter {
    static func string(for binding: HotkeyBinding) -> String {
        var result = ""
        if binding.modifiers & UInt32(controlKey) != 0 { result += "⌃" }
        if binding.modifiers & UInt32(optionKey) != 0 { result += "⌥" }
        if binding.modifiers & UInt32(shiftKey) != 0 { result += "⇧" }
        if binding.modifiers & UInt32(cmdKey) != 0 { result += "⌘" }
        result += KeyCodeNames.name(for: binding.keyCode)
        return result
    }
}

private enum KeyCodeNames {
    static func name(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_S: return "S"
        default: return "key\(keyCode)"
        }
    }
}

private extension Color {
    /// Convert to a serializable RGBA color, normalizing to sRGB.
    var rgba: RGBAColor {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(self)
        return RGBAColor(
            red: Double(ns.redComponent),
            green: Double(ns.greenComponent),
            blue: Double(ns.blueComponent),
            alpha: Double(ns.alphaComponent)
        )
    }
}
