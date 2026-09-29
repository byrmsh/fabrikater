import FabrikaterCore

/// What VoiceOver says unasked when something the user waits on changes: a pane joins Needs You, the host goes offline
/// or comes back, a prompt card appears, a send or answer fails (docs/design.md, "Accessibility"). The views post the
/// text; removing this file and those posts removes the feature.
public enum Announcement {
    /// What VoiceOver reads as the value of a button whose spinner stands in for its title while it sends.
    public static let sendingValue = "Sending"

    /// The app-wide state announcements follow, one value so a view watches it with one `onChange`.
    public struct State: Equatable, Sendable {
        public var connection: ConnectionState
        public var needsYou: [PaneRow]
    }

    /// What changed between two states, in the order to say it.
    public static func changes(from old: State, to new: State) -> [String] {
        [connection(from: old.connection, to: new.connection), needsYou(from: old, to: new)].compactMap { $0 }
    }

    /// Going offline, and coming back after being offline. Not the first connection, which the user started.
    static func connection(from old: ConnectionState, to new: ConnectionState) -> String? {
        switch (old.isOffline, new) {
        case (true, .connected): "Reconnected"
        case (false, .stale), (false, .offline): new.title
        default: nil
        }
    }

    /// The panes that joined Needs You while connected. The group's first fill, at launch or on reconnecting, is not
    /// news: the sidebar shows it.
    static func needsYou(from old: State, to new: State) -> String? {
        guard old.connection == .connected, new.connection == .connected else { return nil }
        let known = Set(old.needsYou.map(\.id))
        let joined = new.needsYou.filter { !known.contains($0.id) }
        guard let first = joined.first else { return nil }
        guard joined.count == 1 else { return "\(joined.count) panes need you" }
        return first.status == .blocked ? "\(first.label) needs input" : "\(first.label) finished its turn"
    }
}

extension ConnectionState {
    var isOffline: Bool {
        switch self {
        case .stale, .offline: true
        case .connecting, .connected: false
        }
    }
}

extension AppStore {
    /// What `Announcement.changes` compares.
    public var announced: Announcement.State {
        Announcement.State(connection: connection, needsYou: needsYou.panes)
    }
}

extension PromptCardStore {
    /// What VoiceOver says as the card appears or shows a new prompt: its heading and question.
    public var announcement: String? {
        isShown ? "\(title). \(question)" : nil
    }
}
