import FabrikaterCore
import Foundation

// M6: the panes waiting on the user, listed above the workspaces, counted on the Dock badge and reached with ⌘1…⌘9.

/// The "Needs You" group: every blocked pane, then every pane whose agent finished a turn the user has not opened yet
/// (unread, B7) and has not started another.
public struct NeedsYou: Equatable, Sendable {
    public static let title = "Needs You"
    /// The panes ⌘1…⌘9 reach.
    public static let numbers = 1...9

    public var panes: [PaneRow] = []

    /// The Dock badge: how many panes wait, or nil when none do.
    public var badge: String? { panes.isEmpty ? nil : String(panes.count) }

    /// The pane at `number` (1 is the first), if the group is that long.
    public func pane(number: Int) -> PaneRow? {
        panes.indices.contains(number - 1) ? panes[number - 1] : nil
    }
}

extension [SidebarSection] {
    /// Blocked panes first, then unread ones, each in sidebar order, so a pane keeps its place until its state changes.
    /// Opening an unread pane reads it and it leaves; a blocked pane stays until its agent moves on.
    var needingYou: NeedsYou {
        let panes = self.panes
        return NeedsYou(
            panes: panes.filter { $0.status == .blocked }
                + panes.filter { $0.isUnread && [.done, .idle].contains($0.status) })
    }
}
