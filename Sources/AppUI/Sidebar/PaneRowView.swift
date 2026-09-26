import AppModel
import FabrikaterCore
import SwiftUI

/// A pane's status dot, agent symbol and title. The title is the label, or the name field while renaming; a plain
/// stack rather than a `Label`, whose title slot does not take keyboard focus for the field. The symbol gets a fixed
/// width so titles line up and a wide symbol never runs into its title.
struct PaneRowView<Title: View>: View {
    let pane: PaneRow
    @ViewBuilder let title: Title

    var body: some View {
        HStack(spacing: 4) {
            StatusDot(status: pane.status)
            Image(systemName: pane.agent.symbolName)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            title
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .foregroundStyle(pane.isDimmed ? .secondary : .primary)
        .help("\(pane.label) (\(pane.id.rawValue)), \(pane.status.title)")
    }
}

extension PaneRowView where Title == Text {
    init(pane: PaneRow) {
        self.init(pane: pane) { Text(pane.label) }
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
