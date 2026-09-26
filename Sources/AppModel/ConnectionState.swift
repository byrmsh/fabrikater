/// Whether the herd on screen is current.
public enum ConnectionState: Equatable, Sendable {
    case connecting
    case connected
    /// The last read failed; the herd shown is the last one that succeeded.
    case stale(String)
    /// The last read failed and there is nothing to show.
    case offline(String)

    public var title: String {
        switch self {
        case .connecting: "Connecting…"
        case .connected: "Connected"
        case .stale: "Offline, showing the last known state"
        case .offline: "Offline"
        }
    }

    /// Why the last read failed, when it did.
    public var failure: String? {
        switch self {
        case .connecting, .connected: nil
        case .stale(let reason), .offline(let reason): reason
        }
    }

    /// What the sidebar says in place of an empty herd.
    public var emptySidebar: EmptySidebar {
        switch self {
        case .connecting: EmptySidebar(title: "Connecting…", detail: nil)
        case .connected: EmptySidebar(title: "No Workspaces", detail: "Herdr has no workspaces open.")
        case .stale(let reason), .offline(let reason): EmptySidebar(title: "Offline", detail: reason)
        }
    }
}

/// The placeholder an empty sidebar shows.
public struct EmptySidebar: Equatable, Sendable {
    public var title: String
    public var detail: String?
}
