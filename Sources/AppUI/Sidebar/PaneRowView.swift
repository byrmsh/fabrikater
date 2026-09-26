import AppModel
import FabrikaterCore
import SwiftUI

struct PaneRowView: View {
    let pane: PaneRow

    var body: some View {
        HStack(spacing: 6) {
            PaneRowIcons(pane: pane)
            Text(pane.label)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .foregroundStyle(pane.isDimmed ? .secondary : .primary)
        .help("\(pane.label) (\(pane.id.rawValue)), \(pane.status.title)")
        .accessibilityElement(children: .combine)
        .accessibilityValue(pane.status.title)
    }
}

/// The status dot and agent symbol in front of a pane's label, also shown while the label is being renamed.
/// The symbol gets a fixed width so labels line up and a wide symbol never runs into its label.
struct PaneRowIcons: View {
    let pane: PaneRow

    var body: some View {
        HStack(spacing: 4) {
            StatusDot(status: pane.status)
            Image(systemName: pane.agent.symbolName)
                .foregroundStyle(.secondary)
                .frame(width: 20)
        }
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
        .accessibilityElement(children: .combine)
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
