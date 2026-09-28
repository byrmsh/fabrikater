import AppModel
import SwiftUI

/// The pane's status and agent, shown in the toolbar next to Reload.
struct PaneStatusView: View {
    let header: PaneHeader

    var body: some View {
        HStack(spacing: 6) {
            StatusDot(status: header.status)
            Text(header.status.title)
            Text(header.agent)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(header.summary)
        .help(header.summary)
    }
}
