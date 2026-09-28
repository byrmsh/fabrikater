import AppModel
import SwiftUI
import TranscriptKit

/// One edit as unified diff lines: removed lines tinted red, added lines green, unchanged lines plain, each line's
/// code highlighted for the file's language.
struct DiffView: View {
    let edit: FileEdit
    let language: CodeLanguage?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Lines that fit are tinted across the whole panel; longer ones scroll sideways.
            ViewThatFits(in: .horizontal) {
                lines
                ScrollView(.horizontal) {
                    lines
                }
            }
            if let omitted = edit.omittedSummary {
                Text(omitted)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .background(.quinary, in: .rect(cornerRadius: 6))
        .padding(.vertical, 2)
    }

    private var lines: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(edit.lines.enumerated()), id: \.offset) { _, line in
                Text(AttributedString(line.kind.marker + " ") + highlighted(line.text))
                    .font(.callout.monospaced())
                    .foregroundStyle(line.kind == .unchanged ? .secondary : .primary)
                    .lineLimit(1)
                    .fixedSize()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(tint(line.kind))
            }
        }
        .textSelection(.enabled)
        .padding(.vertical, 4)
    }

    private func highlighted(_ text: String) -> AttributedString {
        guard let language else { return AttributedString(text) }
        return AttributedString(code: language.tokens(text), dark: colorScheme == .dark)
    }

    private func tint(_ kind: DiffLine.Kind) -> Color {
        switch kind {
        case .unchanged: .clear
        case .added: .green.opacity(0.18)
        case .removed: .red.opacity(0.18)
        }
    }
}
