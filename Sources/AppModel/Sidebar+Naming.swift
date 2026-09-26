import FabrikaterCore
import Foundation

// B1: a local display name per pane replaces Herdr's label in the sidebar, the header and the window title.

extension [SidebarSection] {
    /// The sections with every named pane's label replaced by its name.
    func named(_ names: [PaneID: String]) -> [SidebarSection] {
        guard !names.isEmpty else { return self }
        return map { section in
            var section = section
            section.rows = section.rows.map { $0.named(names) }
            return section
        }
    }
}

extension SidebarRow {
    func named(_ names: [PaneID: String]) -> SidebarRow {
        switch self {
        case .pane(let pane):
            return .pane(pane.named(names))
        case .tab(var tab):
            tab.panes = tab.panes.map { $0.named(names) }
            return .tab(tab)
        }
    }
}

extension PaneRow {
    func named(_ names: [PaneID: String]) -> PaneRow {
        var row = self
        row.label = names[id] ?? label
        return row
    }
}

extension PaneHeader {
    func named(_ names: [PaneID: String], id: PaneID) -> PaneHeader {
        var header = self
        header.title = names[id] ?? title
        return header
    }
}

extension PaneNotes {
    /// The notes after the user typed `text` as `id`'s name over `label`, the name on screen.
    /// Blank text clears the name; unchanged text leaves the notes as they are.
    func renaming(_ id: PaneID, to text: String, over label: String) -> PaneNotes {
        let name = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var notes = self
        if name.isEmpty {
            notes.names[id] = nil
        } else if name != label {
            notes.names[id] = name
        }
        return notes
    }
}
