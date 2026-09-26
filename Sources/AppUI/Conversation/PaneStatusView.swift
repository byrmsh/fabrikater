import AppModel
import SwiftUI

/// The selected pane's status and agent, shown in the toolbar next to Reload. Clicking it shows the session's facts.
struct PaneStatusView: View {
    let store: AppStore
    let header: PaneHeader

    var body: some View {
        Button {
            store.perform(.toggleSessionFacts)
        } label: {
            HStack(spacing: 6) {
                StatusDot(status: header.status)
                Text(header.status.title)
                Text(header.agent)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 6)
        }
        .disabled(!store.isEnabled(.toggleSessionFacts))
        .accessibilityLabel(header.summary)
        .accessibilityHint(AppCommand.toggleSessionFacts.title)
        .help(header.summary)
        .popover(isPresented: isShowingFacts, arrowEdge: .bottom) {
            SessionFactsView(rows: store.conversation.factRows)
        }
    }

    private var isShowingFacts: Binding<Bool> {
        Binding(
            get: { store.isShowingSessionFacts },
            set: { store.perform(.setSessionFactsShown($0)) }
        )
    }
}
