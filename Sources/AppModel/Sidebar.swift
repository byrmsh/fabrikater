import FabrikaterCore
import Foundation
import HerdrKit

/// One workspace in the sidebar.
public struct SidebarSection: Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var rows: [SidebarRow]
    /// A hidden workspace shown by View › Show Hidden Panes (B5).
    public var isHidden = false

    /// The section's heading: the title, marked when the workspace is hidden.
    public var heading: String { isHidden ? "\(title) (Hidden)" : title }
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
    /// When fabrikater last saw one of its panes change (B6).
    public var lastActivity: Date? { panes.compactMap(\.lastActivity).max() }
    /// Whether one of its panes is unread (B7).
    public var isUnread: Bool { panes.contains(where: \.isUnread) }
}

public struct PaneRow: Equatable, Sendable, Identifiable {
    public var id: PaneID
    public var label: String
    public var status: AgentStatus
    public var agent: AgentKind?
    /// A hidden pane shown by View › Show Hidden Panes (B5).
    public var isHidden = false
    /// When fabrikater last saw the pane change (B6).
    public var lastActivity: Date?
    /// The agent finished a turn since the pane was last selected (B7).
    public var isUnread = false
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

extension [SidebarSection] {
    /// The sections with `transform` applied to every pane row, in tabs too. Sidebar features that set a per-pane
    /// value build on this.
    func mappingPanes(_ transform: (PaneRow) -> PaneRow) -> [SidebarSection] {
        map { section in
            var section = section
            section.rows = section.rows.map { $0.mappingPanes(transform) }
            return section
        }
    }

    /// Every pane once, in sidebar order. A pane shown twice (pinned, B4) counts where it first appears.
    var panes: [PaneRow] {
        var seen = Set<PaneID>()
        return flatMap { $0.rows.flatMap(\.panes) }.filter { seen.insert($0.id).inserted }
    }
}

extension SidebarRow {
    func mappingPanes(_ transform: (PaneRow) -> PaneRow) -> SidebarRow {
        switch self {
        case .pane(let pane):
            return .pane(transform(pane))
        case .tab(var tab):
            tab.panes = tab.panes.map(transform)
            return .tab(tab)
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

extension Herd {
    /// "Workspace › Tab", leaving out empty labels.
    func location(of pane: Pane) -> String {
        [workspace(pane.workspaceID)?.label, tab(pane.tabID)?.label]
            .compactMap { $0?.isEmpty == false ? $0 : nil }
            .joined(separator: " › ")
    }
}

extension PaneRow {
    /// What VoiceOver reads for the row: the label (a rename when set), the agent, the status and whether it is unread.
    public var spokenLabel: String {
        "\(label), \(agent.title), \(status.title)\(isUnread ? ", Unread" : "")\(isHidden ? ", Hidden" : "")"
    }
}

extension TabRow {
    /// What VoiceOver reads for the row: the label, the status and whether a pane in it is unread.
    public var spokenLabel: String {
        "\(label), \(status.title)\(isUnread ? ", Unread" : "")"
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

extension AgentKind? {
    /// The agent's name, or "Shell" for a pane without one.
    public var title: String { self?.title ?? "Shell" }
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
