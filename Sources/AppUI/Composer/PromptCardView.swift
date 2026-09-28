import AppModel
import SwiftUI

/// The card above the composer while the agent waits for an answer: what it asks and a button per option, or, when
/// the prompt cannot be read, that it waits (docs/design.md, "Blocked panes: prompt cards").
struct PromptCardView: View {
    let prompt: PromptCardStore
    /// Whether the window can switch to its terminal now: not while it already shows it.
    let canShowTerminal: Bool
    let perform: @MainActor (AppCommand) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(prompt.title, systemImage: "questionmark.bubble")
                .font(.headline)
            if let subject = prompt.subject {
                Text(subject)
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(8)
                    .textSelection(.enabled)
            }
            Text(prompt.question)
                .scaledFont(.body)
                .textSelection(.enabled)
            if !prompt.options.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(prompt.options) { option in
                        OptionButton(option: option, isAnswering: prompt.answering == option.number) {
                            perform(.answerPrompt(option.number))
                        }
                        .disabled(!prompt.canAnswer)
                    }
                }
            }
            if prompt.offersTerminal {
                Button(PromptCardStore.terminalTitle) {
                    perform(PromptCardStore.terminalCommand)
                }
                .controlSize(.small)
                .disabled(!canShowTerminal)
                .help(PromptCardStore.terminalHelp)
            }
            if let notice = prompt.notice {
                Label(notice, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quinary, in: .rect(cornerRadius: 8))
        .padding([.horizontal, .top], 12)
    }
}

/// One option: its key, its label and the explanation under it.
private struct OptionButton: View {
    let option: PromptOption
    let isAnswering: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(option.key)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.label)
                    if let detail = option.detail {
                        Text(detail)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                if isAnswering {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.bordered)
        .help(option.help)
        .accessibilityLabel(option.label)
        .accessibilityHint(option.help)
    }
}
