import FabrikaterCore
import Foundation
import HerdrKit

// M6: a macOS notification when a pane becomes blocked or finishes a turn, unless the user is already looking at it.

/// One notification about a pane. Clicking it selects `paneID`.
public struct PaneAlert: Equatable, Sendable {
    public var paneID: PaneID
    /// The pane's label (a rename when set).
    public var title: String
    /// "Workspace › Tab".
    public var subtitle: String
    /// What happened: "Needs input" or "Finished its turn".
    public var body: String
    /// Whether the notification plays the system sound (Settings).
    public var playsSound = true
}

/// Shows alerts to the user. The composition root passes the system's notification centre.
@MainActor
public protocol Notifier: AnyObject {
    func post(_ alert: PaneAlert)
}

/// Keeps every alert: the default for tests and fixture runs.
@MainActor
public final class RecordingNotifier: Notifier {
    public private(set) var alerts: [PaneAlert] = []

    public init() {}

    public func post(_ alert: PaneAlert) { alerts.append(alert) }
}

extension Herd {
    /// The panes to notify about after the herd went from `old` to this one: each that became blocked, and each that
    /// went from working to done, leaving out `watched` (the selected pane while the app is frontmost) and panes in
    /// `muted` workspaces. A pane new to the herd has no transition, so the first herd after launch notifies nothing.
    func alerting(since old: Herd, watched: PaneID?, muted: Set<String>) -> [Pane] {
        panes.filter { pane in
            guard pane.id != watched, !muted.contains(pane.workspaceID), let before = old.pane(pane.id)?.agentStatus
            else { return false }
            return (pane.agentStatus == .blocked && before != .blocked)
                || (pane.agentStatus == .done && before == .working)
        }
    }
}

extension AgentStatus {
    /// An alert's body for a pane that reached this status.
    var alertBody: String { self == .blocked ? "Needs input" : "Finished its turn" }
}

extension PaneNotes {
    /// The notes with notifications for workspace `id` turned off, or on again.
    func togglingMuted(_ id: String) -> PaneNotes {
        var notes = self
        if notes.mutedWorkspaces.remove(id) == nil {
            notes.mutedWorkspaces.insert(id)
        }
        return notes
    }
}
