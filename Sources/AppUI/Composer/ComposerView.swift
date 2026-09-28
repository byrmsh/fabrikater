import AppModel
import SwiftUI

/// The text field under the conversation, in the main window and each pane window. Return sends; Option-Return inserts
/// a newline (docs/design.md, "Composer").
struct ComposerView: View {
    @Bindable var composer: ComposerStore
    let perform: @MainActor (AppCommand) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let notice = composer.notice {
                Label(notice, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
            HStack(alignment: .bottom, spacing: 8) {
                TextField(composer.placeholder, text: $composer.draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .scaledFont(.body)
                    .lineLimit(1...8)
                    .padding(8)
                    .background(.quinary, in: .rect(cornerRadius: 8))
                    .onSubmit { perform(.send) }
                Button {
                    perform(.send)
                } label: {
                    if composer.isSending {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text(composer.sendTitle)
                    }
                }
                // The window's own shortcut, so ⌘Return in a pane window sends that window's draft, not the Pane menu's.
                .keyboardShortcut(Keymap.chord(for: .send)?.shortcut)
                .disabled(!composer.canSend)
                .help(composer.disabledReason ?? "\(composer.sendTitle) (⌘Return)")
            }
        }
        .padding(12)
    }
}
