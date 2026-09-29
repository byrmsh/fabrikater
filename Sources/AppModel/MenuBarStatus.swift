import FabrikaterCore

// From the Later list: a menu bar item that counts the Needs You panes and lists them, shown while Settings' "Show in
// menu bar" is on. Removing the feature deletes this file, AppUI/MenuBar/ and its line in `FabrikaterApp`.

/// What the menu bar item shows for the host connected to now: its icon, its count and the Needs You panes in its menu.
public struct MenuBarStatus: Equatable, Sendable {
    /// One pane in the menu; choosing it selects the pane in the main window.
    public struct Row: Equatable, Sendable, Identifiable {
        public var id: PaneID
        /// "codex · Needs input".
        public var title: String
    }

    public var rows: [Row]
    /// The number beside the icon, or nil when nothing waits.
    public var count: String?
    /// An SF Symbol: a bell, badged while panes wait, struck through while the host is unreachable.
    public var symbol: String
    /// The menu's first line: the host and how many panes wait on it.
    public var heading: String
    /// What VoiceOver reads for the item in the menu bar.
    public var spokenLabel: String

    /// The menu's item that brings the main window forward.
    public static let openTitle = "Open fabrikater"

    public init(needsYou: NeedsYou, connection: ConnectionState, host: String) {
        rows = needsYou.panes.map { Row(id: $0.id, title: "\($0.label) · \($0.status.title)") }
        count = needsYou.badge
        let waiting = Self.waiting(needsYou.panes.count)
        switch connection {
        case .connecting:
            symbol = "bell"
            heading = "Connecting to \(host)…"
        case .connected:
            symbol = needsYou.panes.isEmpty ? "bell" : "bell.badge"
            heading = "\(host): \(waiting)"
        case .stale:
            symbol = "bell.slash"
            heading = "\(host) is offline; last known: \(waiting)"
        case .offline:
            symbol = "bell.slash"
            heading = "\(host) is offline"
        }
        spokenLabel = "fabrikater, \(heading)"
    }

    private static func waiting(_ count: Int) -> String {
        switch count {
        case 0: "nothing needs you"
        case 1: "1 pane needs you"
        default: "\(count) panes need you"
        }
    }
}

extension HostSession {
    /// The menu bar item for the store connected to now, so it follows a host switch.
    public var menuBar: MenuBarStatus {
        MenuBarStatus(needsYou: store.needsYou, connection: store.connection, host: preferences.connectedHost)
    }

    /// Whether the item is in the menu bar; ⌘-dragging it out of the menu bar turns it off too.
    public var showsMenuBarItem: Bool {
        get { preferences.preferences.showsMenuBarItem }
        set { preferences.set(\.showsMenuBarItem, to: newValue) }
    }
}
