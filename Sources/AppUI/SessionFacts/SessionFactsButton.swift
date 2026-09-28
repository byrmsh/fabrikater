import AppModel
import SwiftUI

/// The toolbar's status, as a button that opens the session facts popover (B11), in the main window and pane windows.
struct SessionFactsButton: View {
    let model: any PaneDetailModel
    let header: PaneHeader

    var body: some View {
        Button {
            model.perform(.toggleSessionFacts)
        } label: {
            PaneStatusView(header: header)
        }
        .disabled(!model.isEnabled(.toggleSessionFacts))
        .accessibilityLabel(header.summary)
        .accessibilityHint(AppCommand.toggleSessionFacts.title)
        .help(header.summary)
        .popover(isPresented: isShowingFacts, arrowEdge: .bottom) {
            SessionFactsView(rows: model.conversation.factRows)
        }
    }

    private var isShowingFacts: Binding<Bool> {
        Binding(
            get: { model.panels.isShowingSessionFacts },
            set: { model.perform(.setSessionFactsShown($0)) }
        )
    }
}
