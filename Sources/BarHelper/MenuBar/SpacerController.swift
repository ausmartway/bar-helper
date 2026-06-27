import AppKit

/// Renders the profile's spacers (REQ-C13) and group placeholders (REQ-C14) as
/// live `NSStatusItem`s in the menu bar.
///
/// A spacer is a real status item showing its label (text/emoji) or a blank
/// gap. A group is represented by a single labeled item that, when clicked,
/// reveals the section so the grouped members are accessible — a pragmatic
/// stand-in for true item-combining, which would require relocating other
/// apps' items (REQ-X03).
final class SpacerController {

    /// Invoked when a group item is clicked, with the section to reveal.
    var onGroupActivated: ((MenuBarSection) -> Void)?

    private var spacerItems: [UUID: NSStatusItem] = [:]
    private var groupItems: [UUID: GroupTarget] = [:]

    /// Reconcile the live status items with the profile's spacers and groups.
    func sync(spacers: [MenuBarSpacer], groups: [ItemGroup]) {
        syncSpacers(spacers)
        syncGroups(groups)
    }

    func clear() {
        spacerItems.values.forEach { NSStatusBar.system.removeStatusItem($0) }
        spacerItems.removeAll()
        groupItems.values.forEach { NSStatusBar.system.removeStatusItem($0.item) }
        groupItems.removeAll()
    }

    // MARK: - Spacers (REQ-C13)

    private func syncSpacers(_ spacers: [MenuBarSpacer]) {
        let wanted = Set(spacers.map(\.id))
        for (id, item) in spacerItems where !wanted.contains(id) {
            NSStatusBar.system.removeStatusItem(item)
            spacerItems[id] = nil
        }
        for spacer in spacers {
            let item = spacerItems[spacer.id]
                ?? NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            if let button = item.button {
                button.title = spacer.label
                // A blank spacer still needs a little width to be grabbable.
                item.length = spacer.label.isEmpty ? 12 : NSStatusItem.variableLength
                button.toolTip = "bar-helper spacer"
            }
            spacerItems[spacer.id] = item
        }
    }

    // MARK: - Groups (REQ-C14)

    private final class GroupTarget {
        let item: NSStatusItem
        var section: MenuBarSection
        var handler: ((MenuBarSection) -> Void)?
        init(item: NSStatusItem, section: MenuBarSection) {
            self.item = item
            self.section = section
        }
        @objc func activate() { handler?(section) }
    }

    private func syncGroups(_ groups: [ItemGroup]) {
        let wanted = Set(groups.map(\.id))
        for (id, target) in groupItems where !wanted.contains(id) {
            NSStatusBar.system.removeStatusItem(target.item)
            groupItems[id] = nil
        }
        for group in groups {
            let target = groupItems[group.id] ?? GroupTarget(
                item: NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength),
                section: .hidden
            )
            if let button = target.item.button {
                button.title = group.name
                button.image = NSImage(systemSymbolName: "square.stack.3d.up",
                                       accessibilityDescription: group.name)
                button.imagePosition = .imageLeading
                button.target = target
                button.action = #selector(GroupTarget.activate)
                button.toolTip = "\(group.name) — \(group.itemIDs.count) items"
            }
            target.handler = { [weak self] section in self?.onGroupActivated?(section) }
            groupItems[group.id] = target
        }
    }
}
