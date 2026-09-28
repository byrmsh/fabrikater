import FabrikaterCore
import Foundation

// B14: View › Sort Panes By orders each workspace's rows as Herdr has them, or by B6's last activity, newest first.

/// How the sidebar orders the rows within each workspace.
public enum PaneOrder: String, CaseIterable, Codable, Sendable {
    case herdr
    case recentActivity

    /// The View menu's submenu holding one item per order.
    public static let menuTitle = "Sort Panes By"

    public var title: String {
        switch self {
        case .herdr: "Herdr Order"
        case .recentActivity: "Recent Activity"
        }
    }
}

extension [SidebarSection] {
    /// The sections with each workspace's rows in `order`. By recent activity, rows fabrikater has seen change come
    /// first, newest first; rows with the same time, and rows with none, keep Herdr's order.
    func sorted(_ order: PaneOrder) -> [SidebarSection] {
        guard order == .recentActivity else { return self }
        return map { section in
            var section = section
            section.rows = section.rows.enumerated()
                .sorted { lhs, rhs in
                    switch (lhs.element.lastActivity, rhs.element.lastActivity) {
                    case (let left?, let right?) where left != right: left > right
                    case (.some, nil): true
                    case (nil, .some): false
                    default: lhs.offset < rhs.offset
                    }
                }
                .map(\.element)
            return section
        }
    }
}

extension SidebarRow {
    /// The pane's last activity, or the tab's most recent pane's.
    var lastActivity: Date? {
        switch self {
        case .pane(let pane): pane.lastActivity
        case .tab(let tab): tab.lastActivity
        }
    }
}
