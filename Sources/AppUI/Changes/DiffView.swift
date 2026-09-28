import SwiftUI
import TranscriptKit

/// One edit as unified diff lines: removed lines tinted red, added lines green, unchanged lines plain.
struct DiffView: View {
    let edit: FileEdit

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ScrollView(.horizontal) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(edit.lines.enumerated()), id: \.offset) { _, line in
                        Text(line.kind.marker + " " + line.text)
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
            if let omitted = edit.omittedSummary {
                Text(omitted)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .background(.quinary, in: .rect(cornerRadius: 6))
        .padding(.vertical, 2)
    }

    private func tint(_ kind: DiffLine.Kind) -> Color {
        switch kind {
        case .unchanged: .clear
        case .added: .green.opacity(0.18)
        case .removed: .red.opacity(0.18)
        }
    }
}
