import FabrikaterCore
import Foundation
import HerdrKit

/// One workspace in the sidebar.
public struct SidebarSection: Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var rows: [SidebarRow]
}

/// A tab with several panes, or a single pane (a tab with one pane collapses to its pane).
public enum SidebarRow: Equatable, Sendable, Identifiable {
    case pane(PaneRow)
    case tab(TabRow)

    public var id: String {
        switch self {
        case .pane(let pane): pane.id.rawValue
        case .tab(let tab): tab.id
        }
    }

    public var panes: [PaneRow] {
        switch self {
        case .pane(let pane): [pane]
        case .tab(let tab): tab.panes
        }
    }
}

public struct TabRow: Equatable, Sendable, Identifiable {
    public var id: String
    public var label: String
    public var status: AgentStatus
    public var panes: [PaneRow]
}

public struct PaneRow: Equatable, Sendable, Identifiable {
    public var id: PaneID
    public var label: String
    public var status: AgentStatus
    public var agent: AgentKind?
    /// Shell panes without an agent are shown dimmed.
    public var isDimmed: Bool { agent == nil }
}

extension SidebarSection {
    /// The herd as sidebar rows: workspaces and tabs by `number`, panes in snapshot order.
    static func sections(for herd: Herd) -> [SidebarSection] {
        let tabsByWorkspace = Dictionary(grouping: herd.tabs, by: \.workspaceID)
        let panesByTab = Dictionary(grouping: herd.panes, by: \.tabID)
        return herd.workspaces.sorted(by: { $0.number < $1.number }).map { workspace in
            let tabs = (tabsByWorkspace[workspace.id] ?? []).sorted(by: { $0.number < $1.number })
            let rows = tabs.compactMap { tab -> SidebarRow? in
                let panes = (panesByTab[tab.id] ?? []).map { PaneRow(pane: $0, tab: tab) }
                switch panes.count {
                case 0: return nil
                case 1: return .pane(panes[0])
                default:
                    let label = tab.label.isEmpty ? tab.id : tab.label
                    return .tab(TabRow(id: tab.id, label: label, status: tab.agentStatus, panes: panes))
                }
            }
            return SidebarSection(
                id: workspace.id, title: workspace.label.isEmpty ? workspace.id : workspace.label, rows: rows)
        }
    }
}

extension PaneRow {
    init(pane: Herd.Pane, tab: Herd.Tab?) {
        self.init(id: pane.id, label: Self.label(for: pane, tab: tab), status: pane.agentStatus, agent: pane.agent)
    }

    /// `terminal_title_stripped`, else the tab label, else the pane id (docs/design.md, "Window").
    static func label(for pane: Herd.Pane, tab: Herd.Tab?) -> String {
        if let title = pane.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            return title
        }
        if let label = tab?.label.trimmingCharacters(in: .whitespacesAndNewlines), !label.isEmpty {
            return label
        }
        return pane.id.rawValue
    }
}

extension AgentStatus {
    /// The status in words, for accessibility labels and help tags.
    public var title: String {
        switch self {
        case .idle: "Idle"
        case .working: "Working"
        case .blocked: "Needs input"
        case .done: "Done"
        case .unknown: "Unknown"
        }
    }
}

extension AgentKind {
    public var title: String {
        switch self {
        case .claude: "Claude"
        case .codex: "Codex"
        case .pi: "pi"
        case .omp: "omp"
        case .opencode: "OpenCode"
        case .grok: "Grok"
        case .other(let name): name
        }
    }
}
