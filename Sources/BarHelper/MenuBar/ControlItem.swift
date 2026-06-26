import AppKit

/// The always-visible primary status item: bar-helper's own icon and the menu
/// that gives access to settings, the hidden-items bar, and quit. This is the
/// user's anchor — distinct from the section separators, which only bound the
/// hide/show regions.
final class ControlItem: NSObject, NSMenuDelegate {

    struct Commands {
        let openSettings: () -> Void
        let toggleHidden: () -> Void
        let showHiddenBar: () -> Void
        let quit: () -> Void
    }

    private let statusItem: NSStatusItem
    private let commands: Commands

    init(commands: Commands) {
        self.commands = commands
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "menubar.rectangle",
                                   accessibilityDescription: "bar-helper")
            button.image?.isTemplate = true
        }
        statusItem.menu = makeMenu()
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        let toggle = NSMenuItem(title: "Toggle Hidden Items",
                                action: #selector(toggleHidden), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)

        let bar = NSMenuItem(title: "Show Hidden Items Bar",
                             action: #selector(showHiddenBar), keyEquivalent: "")
        bar.target = self
        menu.addItem(bar)

        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Settings…",
                                  action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit bar-helper",
                              action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    func dispose() {
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    @objc private func toggleHidden() { commands.toggleHidden() }
    @objc private func showHiddenBar() { commands.showHiddenBar() }
    @objc private func openSettings() { commands.openSettings() }
    @objc private func quit() { commands.quit() }
}
