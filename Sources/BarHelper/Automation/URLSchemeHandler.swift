import AppKit

/// Handles the `barhelper://` URL scheme (REQ-A03), the automation entry point
/// that AppleScript (`open location`) and the Shortcuts app ("Open URL") can
/// drive. Examples:
///
///   barhelper://show?section=hidden
///   barhelper://hide
///   barhelper://toggle?section=alwaysHidden
///   barhelper://profile?name=Work
///
/// Registered via the Apple Event manager so it works for a running agent
/// without bouncing through `LSSetDefaultHandler`. The matching
/// `CFBundleURLTypes` entry is declared in Resources/Info.plist.
final class URLSchemeHandler: NSObject {

    struct Commands {
        let reveal: (MenuBarSection) -> Void
        let hide: () -> Void
        let toggle: (MenuBarSection) -> Void
        let switchProfile: (String) -> Void
    }

    private let commands: Commands
    private(set) var isEnabled = false

    init(commands: Commands) {
        self.commands = commands
        super.init()
    }

    /// Begin listening for `barhelper://` URLs.
    func start() {
        guard !isEnabled else { return }
        isEnabled = true
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func stop() {
        guard isEnabled else { return }
        isEnabled = false
        NSAppleEventManager.shared().removeEventHandler(
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc private func handleURLEvent(_ event: NSAppleEventDescriptor,
                                      withReplyEvent reply: NSAppleEventDescriptor) {
        guard let string = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: string) else { return }
        dispatch(url)
    }

    /// Parse and execute a `barhelper://` URL. Exposed (non-private) so it can
    /// be unit-tested without an Apple Event round-trip.
    func dispatch(_ url: URL) {
        guard url.scheme == "barhelper" else { return }
        let host = url.host ?? ""
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems ?? []
        let section = query.first { $0.name == "section" }?.value
            .flatMap(MenuBarSection.init(rawValue:))

        switch host {
        case "show":
            commands.reveal(section ?? .hidden)
        case "hide":
            commands.hide()
        case "toggle":
            commands.toggle(section ?? .hidden)
        case "profile":
            if let name = query.first(where: { $0.name == "name" })?.value {
                commands.switchProfile(name)
            }
        default:
            break
        }
    }
}
