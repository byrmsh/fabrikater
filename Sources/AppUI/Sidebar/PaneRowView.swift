import AppModel
import FabrikaterCore
import SwiftUI

/// A pane's status dot, then its agent symbol and title. The dot sits outside the `Label` so the symbol keeps the
/// sidebar's icon slot to itself. The title is the label, or the name field while renaming.
struct PaneRowView<Title: View>: View {
    let pane: PaneRow
    @ViewBuilder let title: Title

    var body: some View {
        HStack(spacing: 4) {
            StatusDot(status: pane.status)
            Label {
                title
                    .lineLimit(1)
                    .truncationMode(.tail)
            } icon: {
                Image(systemName: pane.agent.symbolName)
                    .foregroundStyle(.secondary)
            }
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
