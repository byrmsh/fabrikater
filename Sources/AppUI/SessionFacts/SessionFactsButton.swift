import AppModel
import SwiftUI

/// The main window's toolbar status, as a button that opens the session facts popover (B11).
struct SessionFactsButton: View {
    let store: AppStore
    let header: PaneHeader

    var body: some View {
        Button {
            store.perform(.toggleSessionFacts)
        } label: {
            PaneStatusView(header: header)
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
