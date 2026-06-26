import AppKit
import SwiftUI

/// A secondary, Ice-Bar / Bartender-Bar-style floating panel that lists the
/// hidden menu-bar items in a strip beneath the menu bar (REQ-C10). This is the
/// alternative to expanding the main bar, keeping the primary menu bar tidy.
final class HiddenItemsPanel {

    private let settings: SettingsStore
    private var panel: NSPanel?

    init(settings: SettingsStore) {
        self.settings = settings
    }

    func toggle() {
        if panel?.isVisible == true {
            close()
        } else {
            show()
        }
    }

    private func show() {
        let panel = self.panel ?? makePanel()
        self.panel = panel
        positionUnderMenuBar(panel)
        panel.makeKeyAndOrderFront(nil)
    }

    private func close() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let content = HiddenItemsBar(settings: settings)
        let hosting = NSHostingController(rootView: content)
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 44),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .hudWindow],
            backing: .buffered,
            defer: true
        )
        panel.contentViewController = hosting
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        return panel
    }

    private func positionUnderMenuBar(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let size = panel.frame.size
        let x = screen.frame.maxX - size.width - 12
        let y = screen.frame.maxY - NSStatusBar.system.thickness - size.height - 4
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

/// SwiftUI content for the hidden-items strip.
private struct HiddenItemsBar: View {
    @ObservedObject var settings: SettingsStore

    private var hiddenItems: [String] {
        settings.profile.sectionAssignments
            .filter { $0.value != .visible }
            .map { $0.key }
            .sorted()
    }

    var body: some View {
        HStack(spacing: 10) {
            if hiddenItems.isEmpty {
                Text("No hidden items")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                ForEach(hiddenItems, id: \.self) { item in
                    Text(item)
                        .font(.callout)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
    }
}
