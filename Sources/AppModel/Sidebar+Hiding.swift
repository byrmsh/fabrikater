import FabrikaterCore
import Foundation

// B5: panes and workspaces the user hid drop out of the sidebar, and so do shell panes when shells are off. View ›
// Show Hidden Panes brings hidden ones back, marked as hidden.

/// What the sidebar leaves out, and whether it shows it anyway.
public struct Hiding: Equatable, Sendable {
    /// Kept for panes and workspaces that are gone, in case they come back.
    public var panes: Set<PaneID> = []
    public var workspaces: Set<String> = []
    public var showHidden = false
    public var showShells = true

    public init(
        panes: Set<PaneID> = [], workspaces: Set<String> = [], showHidden: Bool = false, showShells: Bool = true
    ) {
        self.panes = panes
        self.workspaces = workspaces
        self.showHidden = showHidden
        self.showShells = showShells
    }
}

extension [SidebarSection] {
    /// The sections without hidden panes, hidden workspaces and (when shells are off) shell panes. With `showHidden`,
    /// hidden panes and workspaces stay, marked `isHidden`. A section or tab that filtering empties is dropped, and a
    /// tab left with one pane becomes that pane's row, as in `sections(for:)`.
    func hiding(_ hiding: Hiding) -> [SidebarSection] {
        compactMap { section in
            let isHidden = hiding.workspaces.contains(section.id)
            if isHidden && !hiding.showHidden { return nil }
            let rows = section.rows.compactMap { $0.hiding(hiding) }
            if rows.isEmpty && !section.rows.isEmpty { return nil }
            var section = section
            section.rows = rows
            section.isHidden = isHidden
            return section
        }
    }
}

extension SidebarRow {
    fileprivate func hiding(_ hiding: Hiding) -> SidebarRow? {
        let panes = panes.compactMap { pane -> PaneRow? in
            if pane.agent == nil && !hiding.showShells { return nil }
            let isHidden = hiding.panes.contains(pane.id)
            if isHidden && !hiding.showHidden { return nil }
            var pane = pane
            pane.isHidden = isHidden
            return pane
        }
        switch (self, panes.count) {
        case (_, 0): return nil
        case (.pane, _): return .pane(panes[0])
        case (.tab, 1): return .pane(panes[0])
        case (.tab(var tab), _):
            tab.panes = panes
            return .tab(tab)
        }
    }
}

extension PaneNotes {
    /// The notes with `id` hidden, or shown again if it was hidden.
    func togglingHidden(_ id: PaneID) -> PaneNotes {
        var notes = self
        notes.hiding.panes.formSymmetricDifference([id])
        return notes
    }

    /// The notes with the workspace `id` hidden, or shown again if it was hidden.
    func togglingHiddenWorkspace(_ id: String) -> PaneNotes {
        var notes = self
        notes.hiding.workspaces.formSymmetricDifference([id])
        return notes
    }
}

extension Hiding: Codable {
    private enum CodingKeys: String, CodingKey {
        case panes
        case workspaces
        case showHidden
        case showShells
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let panes = try container.decodeIfPresent([String].self, forKey: .panes) ?? []
        self.panes = Set(panes.compactMap { PaneID($0) })
        workspaces = try container.decodeIfPresent(Set<String>.self, forKey: .workspaces) ?? []
        showHidden = try container.decodeIfPresent(Bool.self, forKey: .showHidden) ?? false
        showShells = try container.decodeIfPresent(Bool.self, forKey: .showShells) ?? true
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(panes.map(\.rawValue).sorted(), forKey: .panes)
        try container.encode(workspaces.sorted(), forKey: .workspaces)
        try container.encode(showHidden, forKey: .showHidden)
        try container.encode(showShells, forKey: .showShells)
    }
}
