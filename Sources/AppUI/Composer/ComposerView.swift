import AppModel
import SwiftUI

/// The text field under the conversation. Return sends; Option-Return inserts a newline (docs/design.md, "Composer").
struct ComposerView: View {
    let store: AppStore

    var body: some View {
        @Bindable var composer = store.composer
        VStack(alignment: .leading, spacing: 6) {
            if let error = composer.error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
            HStack(alignment: .bottom, spacing: 8) {
                TextField(composer.placeholder, text: $composer.draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...8)
                    .padding(8)
                    .background(.quinary, in: .rect(cornerRadius: 8))
                    .onSubmit { store.perform(.send) }
                    .disabled(composer.disabledReason != nil)
                Button {
                    store.perform(.send)
                } label: {
                    if composer.isSending {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text(composer.sendTitle)
                    }
                }
                .disabled(!store.isEnabled(.send))
                .help(composer.disabledReason ?? "\(composer.sendTitle) (⌘Return)")
            }
        }
        .padding(12)
    }
}
