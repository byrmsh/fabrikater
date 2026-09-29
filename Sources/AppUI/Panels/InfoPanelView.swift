import AppModel
import SwiftUI

/// One panel's content, wherever it is docked.
struct InfoPanelView: View {
    let panel: InfoPanel
    let model: any PaneDetailModel

    var body: some View {
        switch panel {
        case .plan: TodoPlanView(todos: model.conversation.transcript.todos)
        case .changes:
            ChangesView(panel: model.conversation.changesPanel, perform: { model.perform($0) })
                .id(model.conversation.paneID)
        case .facts: SessionFactsView(rows: model.conversation.factRows)
        }
    }
}
