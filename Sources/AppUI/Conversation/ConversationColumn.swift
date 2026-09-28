import AppModel
import SwiftUI
import TranscriptKit

/// A conversation's plan, when it has one, above its transcript: the main window's detail and a pane window alike.
struct ConversationColumn: View {
    let conversation: ConversationStore
    let perform: @MainActor (AppCommand) -> Void

    var body: some View {
        if !conversation.transcript.todos.isEmpty {
            TodoPlanView(todos: conversation.transcript.todos)
            Divider()
        }
        TranscriptView(conversation: conversation, perform: perform)
    }
}
