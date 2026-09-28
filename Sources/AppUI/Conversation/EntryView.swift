import AppModel
import SwiftUI
import TranscriptKit

/// One transcript entry: a user turn, assistant text and tool calls, or a muted summary or note.
struct EntryView: View {
    let entry: TranscriptEntry
    /// Shows only the first lines of the entry's text.
    var isCollapsed = false
    /// Show All or Show Less, when the entry is long enough to collapse.
    var toggle: AppCommand?
    var perform: @MainActor (AppCommand) -> Void = { _ in }

    var body: some View {
        switch entry.role {
        case .user:
            content
                .scaledFont(.body)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary, in: .rect(cornerRadius: 8))
        case .assistant:
            content
                .scaledFont(.body)
        case .summary, .note:
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: entry.role == .summary ? "text.append" : "info.circle")
                content
            }
            .scaledFont(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 4) {
            parts
            if let toggle {
                Button(toggle.title) { perform(toggle) }
                    .buttonStyle(.link)
                    .foregroundStyle(.tint)
                    .scaledFont(.callout)
                    // A link-style button exposes neither its title nor a label to accessibility, only its help tag.
                    .help(toggle.title)
            }
        }
    }

    private var parts: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(entry.parts.enumerated()), id: \.offset) { _, part in
                switch part {
                case .text(let text, _):
                    if isCollapsed {
                        Text(AttributedString(inlineMarkdown: text))
                            .lineLimit(Collapsing.visibleLines)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        MarkdownView(text)
                            .textSelection(.enabled)
                    }
                case .tool(let call):
                    ToolCallView(call: call)
                }
            }
        }
    }
}
