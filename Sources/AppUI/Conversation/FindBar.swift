import AppModel
import SwiftUI

/// The find bar over a conversation (⌘F), like Safari's: the field, the match count, previous and next, and Done.
/// Return finds the next match, Shift-Return the previous one, Esc closes the bar.
struct FindBar: View {
    let conversation: ConversationStore
    let perform: @MainActor (AppCommand) -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            TextField(AppCommand.searchConversation("").title, text: query, prompt: Text("Find in Conversation"))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 320)
                .focused($isFocused)
                .onSubmit { perform(.findNext) }
                .onKeyPress(.return, phases: .down) { press in
                    guard press.modifiers.contains(.shift) else { return .ignored }
                    perform(.findPrevious)
                    return .handled
                }
                .onExitCommand { perform(.closeFind) }
            if let status = conversation.find.status {
                Text(status)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            ControlGroup {
                stepButton(.findPrevious, systemImage: "chevron.left")
                stepButton(.findNext, systemImage: "chevron.right")
            }
            .fixedSize()
            if conversation.canFindEarlier {
                Button(AppCommand.loadEarlier.title) { perform(.loadEarlier) }
                    .help(AppCommand.loadEarlier.title)
            }
            Spacer(minLength: 0)
            Button(AppCommand.closeFind.title) { perform(.closeFind) }
                .help(AppCommand.closeFind.title)
        }
        .controlSize(.small)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .onAppear { isFocused = true }
        .onChange(of: conversation.find.focusRequests) { isFocused = true }
    }

    private func stepButton(_ command: AppCommand, systemImage: String) -> some View {
        Button {
            perform(command)
        } label: {
            Label(command.title, systemImage: systemImage)
                .labelStyle(.iconOnly)
        }
        .disabled(conversation.find.matches.isEmpty)
        .help(command.title)
    }

    private var query: Binding<String> {
        Binding(get: { conversation.find.query }, set: { perform(.searchConversation($0)) })
    }
}
