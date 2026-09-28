import FabrikaterCore
import Foundation
import HerdrKit

// B7: a pane whose agent finishes a turn while another pane is selected shows as unread until it is next selected.

extension [SidebarSection] {
    /// The sections with every unread pane marked.
    func unread(_ ids: Set<PaneID>) -> [SidebarSection] {
        guard !ids.isEmpty else { return self }
        return mappingPanes { pane in
            var pane = pane
            pane.isUnread = ids.contains(pane.id)
            return pane
        }
    }
}

extension PaneNotes {
    /// The notes after the herd went from `old` to `new`: each pane other than `selection` whose agent stopped working
    /// (now done or idle) becomes unread.
    func markingFinishedTurns(from old: Herd, to new: Herd, except selection: PaneID?) -> PaneNotes {
        let finished = new.panes.filter { pane in
            pane.id != selection && [.done, .idle].contains(pane.agentStatus)
                && old.pane(pane.id)?.agentStatus == .working
        }
        guard !finished.isEmpty else { return self }
        var notes = self
        notes.unread.formUnion(finished.map(\.id))
        return notes
    }

    /// The notes with `id` read, as when it is selected.
    func reading(_ id: PaneID?) -> PaneNotes {
        guard let id, unread.contains(id) else { return self }
        var notes = self
        notes.unread.remove(id)
        return notes
    }
}
