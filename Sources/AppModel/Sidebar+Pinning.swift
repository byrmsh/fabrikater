import FabrikaterCore
import Foundation

// B4: pinned panes also appear in a Pinned section at the top of the sidebar, in the order they were pinned.

extension [SidebarSection] {
    /// The sections with a Pinned section on top holding each pinned pane still in the herd, in pin order.
    func pinned(_ pins: [PaneID]) -> [SidebarSection] {
        let rows = Dictionary(panes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let pinnedRows = pins.compactMap { rows[$0] }.map(SidebarRow.pane)
        guard !pinnedRows.isEmpty else { return self }
        return [SidebarSection(id: "fabrikater.pinned", title: "Pinned", rows: pinnedRows)] + self
    }
}

extension PaneNotes {
    /// The notes with `id` pinned at the end of the Pinned section, or unpinned if it was pinned.
    func togglingPin(_ id: PaneID) -> PaneNotes {
        var notes = self
        if let index = pins.firstIndex(of: id) {
            notes.pins.remove(at: index)
        } else {
            notes.pins.append(id)
        }
        return notes
    }
}
