import SwiftUI
import TranscriptKit

/// The agent's current plan as a compact checklist, in its panel under a header with its progress.
struct TodoPlanView: View {
    let todos: [Todo]
    @Environment(\.textScale) private var scale

    /// Longer plans scroll inside the panel so the conversation keeps its room.
    private static let visibleRows = 6

    var body: some View {
        Group {
            if todos.count > Self.visibleRows {
                ScrollView {
                    rows
                }
                .frame(height: Double(Self.visibleRows) * 20 * scale)
            } else {
                rows
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(todos.enumerated()), id: \.offset) { _, todo in
                TodoRow(todo: todo)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TodoRow: View {
    let todo: Todo

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: symbol)
                .foregroundStyle(todo.status == .inProgress ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .accessibilityLabel(todo.status.title)
            Text(todo.title)
                .scaledFont(.callout)
                .fontWeight(todo.status == .inProgress ? .medium : .regular)
                .foregroundStyle(todo.status == .completed ? .secondary : .primary)
                .strikethrough(todo.status == .completed)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .help(todo.title)
    }

    private var symbol: String {
        switch todo.status {
        case .pending: "circle"
        case .inProgress: "circle.inset.filled"
        case .completed: "checkmark.circle.fill"
        }
    }
}
