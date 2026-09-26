import SwiftUI
import TranscriptKit

/// One transcript entry: a user turn, assistant text and tool calls, or a muted summary or note.
struct EntryView: View {
    let entry: TranscriptEntry

    var body: some View {
        switch entry.role {
        case .user:
            parts
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary, in: .rect(cornerRadius: 8))
        case .assistant:
            parts
        case .summary, .note:
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: entry.role == .summary ? "text.append" : "info.circle")
                parts
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var parts: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(entry.parts.enumerated()), id: \.offset) { _, part in
                switch part {
                case .text(let text, _):
                    Text(markdown(text))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                case .tool(let call):
                    ToolCallView(call: call)
                }
            }
        }
    }

    // TODO(M2): full markdown (code blocks, tables) with Textual.
    private func markdown(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}
