import AppModel
import SwiftUI

/// The top of a clipped conversation: Load Earlier Messages, or why earlier messages cannot be shown.
struct EarlierMessagesRow: View {
    let conversation: ConversationStore
    let perform: @MainActor (AppCommand) -> Void

    var body: some View {
        Group {
            if let note = conversation.earlierNote {
                Text(note)
                    .foregroundStyle(.secondary)
            } else {
                Button(AppCommand.loadEarlier.title) { perform(.loadEarlier) }
                    .disabled(!conversation.canLoadEarlier)
            }
        }
        .scaledFont(.callout)
        .frame(maxWidth: .infinity)
    }
}
