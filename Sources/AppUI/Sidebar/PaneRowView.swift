import AppModel
import FabrikaterCore
import SwiftUI

struct PaneRowView: View {
    let pane: PaneRow

    var body: some View {
        Label {
            Text(pane.label)
                .lineLimit(1)
                .truncationMode(.tail)
        } icon: {
            HStack(spacing: 4) {
                StatusDot(status: pane.status)
                Image(systemName: pane.agent.symbolName)
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(pane.isDimmed ? .secondary : .primary)
        .help("\(pane.label) (\(pane.id.rawValue)), \(pane.status.title)")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(pane.label)
        .accessibilityValue(pane.status.title)
    }
}

struct TabRowView: View {
    let tab: TabRow

    var body: some View {
        Label {
            Text(tab.label)
                .lineLimit(1)
        } icon: {
            StatusDot(status: tab.status)
        }
        .help("\(tab.label), \(tab.status.title)")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tab.label)
        .accessibilityValue(tab.status.title)
    }
}

extension AgentKind? {
    /// The SF Symbol beside a pane's label.
    var symbolName: String {
        switch self {
        case .none: "terminal"
        case .some(.claude): "sparkle"
        case .some(.codex): "chevron.left.forwardslash.chevron.right"
        default: "cpu"
        }
    }
}
