import AppModel
import SwiftUI
import TranscriptKit

/// A conversation's find bar while it is open above its transcript: the main window's detail and a pane window alike.
struct ConversationColumn: View {
    let conversation: ConversationStore
    let perform: @MainActor (AppCommand) -> Void

    var body: some View {
        if conversation.find.isShown {
            FindBar(conversation: conversation, perform: perform)
            Divider()
        }
        TranscriptView(conversation: conversation, perform: perform)
    }
}
