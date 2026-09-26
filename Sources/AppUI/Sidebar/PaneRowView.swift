import AppModel
import FabrikaterCore
import SwiftUI

/// A pane's status dot, agent symbol and label (or the name field in place of the label while renaming), then the unread
/// dot. A plain stack rather than a `Label`, whose title slot does not take keyboard focus for the field. The symbol gets
/// a fixed width so labels line up and a wide symbol never runs into its label.
struct PaneRowView: View {
    let pane: PaneRow
    var renameField: RenameField?

    var body: some View {
        HStack(spacing: 4) {
            StatusDot(status: pane.status)
            Image(systemName: pane.agent.symbolName)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            if let renameField {
                renameField
            } else {
                Text(pane.label)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .accessibilityLabel(pane.spokenLabel)
            }
            if pane.isUnread {
                Spacer(minLength: 4)
                UnreadDot()
            }
        }
        .foregroundStyle(pane.isDimmed ? .secondary : .primary)
        .help("\(pane.label) (\(pane.id.rawValue)), \(pane.status.title)")
    }
}

struct TabRowView: View {
    let tab: TabRow

    var body: some View {
        Label {
            HStack(spacing: 4) {
                Text(tab.label)
                    .lineLimit(1)
                if tab.isUnread {
                    Spacer(minLength: 4)
                    UnreadDot()
                }
            }
        } icon: {
            StatusDot(status: tab.status)
        }
        .help(tab.spokenLabel)
        // The sidebar turns a disclosure label into a heading, which drops its accessibility label but keeps its value.
        .accessibilityValue(tab.spokenLabel)
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
