import AppKit
import AppModel
import SwiftUI

/// The text field under the conversation, in the main window and each pane window. Return sends and Option-Return
/// inserts a newline, or with Settings' Send with ⌘Return, Return inserts a newline (docs/design.md, "Composer").
struct ComposerView: View {
    @Bindable var composer: ComposerStore
    let perform: @MainActor (AppCommand) -> Void
    @Environment(\.sendKey) private var sendKey

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            KeyBar(composer: composer, perform: perform)
            if let notice = composer.notice {
                Label(notice, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
            HStack(alignment: .bottom, spacing: 8) {
                TextField(sendKey.composerPlaceholder, text: $composer.draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .scaledFont(.body)
                    .lineLimit(1...8)
                    .padding(8)
                    .background(.quinary, in: .rect(cornerRadius: 8))
                    .onSubmit {
                        if sendKey == .return { perform(.send) }
                    }
                    .onKeyPress(keys: [.return], phases: .down) { press in
                        guard sendKey == .commandReturn, press.modifiers.isEmpty else { return .ignored }
                        // What Option-Return does: a newline at the insertion point, from the field's own editor.
                        NSApp.sendAction(
                            #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)), to: nil, from: nil)
                        return .handled
                    }
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
                // The spinner that stands in for the title while sending has no name of its own.
                .accessibilityLabel(composer.sendTitle)
                .accessibilityValue(composer.isSending ? Announcement.sendingValue : "")
                .keyboardShortcut(Keymap.chord(for: .send)?.shortcut)
                .disabled(!composer.canSend)
                .help(composer.disabledReason ?? "\(composer.sendTitle) (⌘Return)")
            }
        }
        .padding(12)
    }
}
