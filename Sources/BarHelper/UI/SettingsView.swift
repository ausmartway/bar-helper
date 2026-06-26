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

            LayoutPane(settings: settings)
                .tabItem { Label("Layout", systemImage: "ruler") }

            AppearancePane(settings: settings)
                .tabItem { Label("Appearance", systemImage: "paintbrush") }

            HotkeysPane(settings: settings)
                .tabItem { Label("Hotkeys", systemImage: "command") }

            TriggersPane(settings: settings)
                .tabItem { Label("Triggers", systemImage: "bolt") }

            AutomationPane(settings: settings)
                .tabItem { Label("Automation", systemImage: "terminal") }

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

            // REQ-C19: separator/divider icon customization.
            Section("Separator icons") {
                Toggle("Show divider icons", isOn: bind(\.appearance.showDividerIcons))
                Picker("Separator symbol", selection: bind(\.appearance.separatorIconSymbol)) {
                    Text("Chevron").tag("chevron.left")
                    Text("Ellipsis").tag("ellipsis")
                    Text("Circle").tag("circle.fill")
                    Text("Line").tag("line.diagonal")
                }
                .disabled(!settings.profile.appearance.showDividerIcons)
            }

            // REQ-C21: screen-edge styling.
            Section("Screen edges") {
                Toggle("Rounded screen corners", isOn: bind(\.appearance.roundedScreenCorners))
                Toggle("Remove background behind menu bar", isOn: bind(\.appearance.backgroundRemoval))
            }

            // REQ-C20: light/dark + per-display styling.
            Section("Light / Dark & displays") {
                Toggle("Separate dark-mode appearance", isOn: Binding(
                    get: { settings.profile.darkAppearance != nil },
                    set: { on in
                        settings.update { $0.darkAppearance = on ? $0.appearance : nil }
                    }
                ))
                Toggle("Distinct styling per display / Space", isOn: bind(\.perDisplayStyling))
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

// MARK: - Layout (REQ-C12/C13/C14/C15)

private struct LayoutPane: View {
    @ObservedObject var settings: SettingsStore
    @State private var newSpacerLabel = ""
    @State private var newGroupName = ""

    var body: some View {
        Form {
            Section("Item spacing") {
                Slider(value: Binding(
                    get: { Double(settings.profile.layout.itemSpacing) },
                    set: { newValue in settings.update { $0.layout.itemSpacing = Int(newValue) } }
                ), in: 0...24, step: 1) { Text("Spacing") }
                Text("\(settings.profile.layout.itemSpacing)pt between items — applies after the menu bar restarts.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("New items") {
                Picker("Default section for new items", selection: Binding(
                    get: { settings.profile.layout.defaultSectionForNewItems },
                    set: { newValue in settings.update { $0.layout.defaultSectionForNewItems = newValue } }
                )) {
                    ForEach(MenuBarSection.allCases) { Text($0.displayName).tag($0) }
                }
                Toggle("Swap shown/hidden on small screens", isOn: Binding(
                    get: { settings.profile.layout.swapShownHiddenOnSmallScreen },
                    set: { v in settings.update { $0.layout.swapShownHiddenOnSmallScreen = v } }
                ))
            }

            Section("Spacers") {
                ForEach(settings.profile.spacers) { spacer in
                    HStack {
                        Text(spacer.label.isEmpty ? "(blank spacer)" : spacer.label)
                        Spacer()
                        Text(spacer.section.displayName).foregroundStyle(.secondary)
                        Button(role: .destructive) {
                            settings.update { p in p.spacers.removeAll { $0.id == spacer.id } }
                        } label: { Image(systemName: "trash") }
                        .buttonStyle(.borderless)
                    }
                }
                HStack {
                    TextField("Spacer label or emoji", text: $newSpacerLabel)
                        .textFieldStyle(.roundedBorder)
                    Button("Add spacer") {
                        settings.update { $0.spacers.append(MenuBarSpacer(label: newSpacerLabel, section: .hidden)) }
                        newSpacerLabel = ""
                    }
                }
            }

            Section("Groups") {
                ForEach(settings.profile.groups) { group in
                    HStack {
                        Text(group.name)
                        Spacer()
                        Text("\(group.itemIDs.count) items").foregroundStyle(.secondary)
                        Button(role: .destructive) {
                            settings.update { p in p.groups.removeAll { $0.id == group.id } }
                        } label: { Image(systemName: "trash") }
                        .buttonStyle(.borderless)
                    }
                }
                HStack {
                    TextField("New group name", text: $newGroupName)
                        .textFieldStyle(.roundedBorder)
                    Button("Add group") {
                        let trimmed = newGroupName.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        settings.update { $0.groups.append(ItemGroup(name: trimmed)) }
                        newGroupName = ""
                    }
                    .disabled(newGroupName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Triggers (REQ-A01)

private struct TriggersPane: View {
    @ObservedObject var settings: SettingsStore
    @State private var newName = ""
    @State private var newKind: TriggerCondition.Kind = .onBattery

    var body: some View {
        VStack(alignment: .leading) {
            Text("Automation triggers")
                .font(.headline)
            Text("Show, hide, or switch profiles automatically when a condition is met.")
                .font(.caption).foregroundStyle(.secondary)

            List {
                ForEach(settings.profile.triggers) { trigger in
                    HStack {
                        Toggle("", isOn: Binding(
                            get: { trigger.enabled },
                            set: { v in settings.update { p in
                                if let i = p.triggers.firstIndex(where: { $0.id == trigger.id }) { p.triggers[i].enabled = v }
                            } }
                        )).labelsHidden()
                        VStack(alignment: .leading) {
                            Text(trigger.name)
                            Text("\(trigger.condition.kind.displayName) → \(trigger.action.kind.displayName)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            settings.update { p in p.triggers.removeAll { $0.id == trigger.id } }
                        } label: { Image(systemName: "trash") }
                        .buttonStyle(.borderless)
                    }
                }
            }

            HStack {
                TextField("Trigger name", text: $newName)
                    .textFieldStyle(.roundedBorder)
                Picker("", selection: $newKind) {
                    ForEach(TriggerCondition.Kind.allCases) { Text($0.displayName).tag($0) }
                }.labelsHidden().frame(width: 150)
                Button("Add") {
                    let trimmed = newName.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    let condition = TriggerCondition(kind: newKind, batteryThreshold: 20,
                                                     scheduleStartHour: 9, scheduleEndHour: 17)
                    settings.update {
                        $0.triggers.append(Trigger(name: trimmed, condition: condition,
                                                   action: TriggerAction(kind: .hideItems)))
                    }
                    newName = ""
                }
                .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
    }
}

// MARK: - Automation (REQ-A02/A03)

private struct AutomationPane: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        Form {
            Section("Behavior") {
                Toggle("Briefly reveal an item when it updates", isOn: Binding(
                    get: { settings.profile.automation.temporaryRevealOnActivity },
                    set: { v in settings.update { $0.automation.temporaryRevealOnActivity = v } }
                ))
                Toggle("Hide app menus that overlap revealed items", isOn: Binding(
                    get: { settings.profile.hideOverlappingAppMenus },
                    set: { v in settings.update { $0.hideOverlappingAppMenus = v } }
                ))
            }

            Section("Scripting (REQ-A03)") {
                Toggle("Enable barhelper:// URL scheme", isOn: Binding(
                    get: { settings.profile.automation.urlSchemeEnabled },
                    set: { v in settings.update { $0.automation.urlSchemeEnabled = v } }
                ))
                Text("Drive bar-helper from AppleScript or Shortcuts, e.g.:")
                    .font(.caption).foregroundStyle(.secondary)
                Text("open location \"barhelper://toggle?section=hidden\"")
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
        .formStyle(.grouped)
        .padding()
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
