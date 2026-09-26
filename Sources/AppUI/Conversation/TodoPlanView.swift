import SwiftUI
import TranscriptKit

/// The agent's current plan as a compact checklist above the conversation; the caller hides it when there is none.
struct TodoPlanView: View {
    let todos: [Todo]
    @ViewState private var isExpanded = true
    @Environment(\.textScale) private var scale

    /// Longer plans scroll inside the panel so the conversation keeps its room.
    private static let visibleRows = 6

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            if todos.count > Self.visibleRows {
                ScrollView {
                    rows
                }
                .frame(height: Double(Self.visibleRows) * 20 * scale)
            } else {
                rows
            }
        } label: {
            HStack(spacing: 6) {
                Text("Plan")
                    .scaledFont(.callout)
                    .fontWeight(.semibold)
                Text(Todo.progress(of: todos))
                    .scaledFont(.callout)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(todos.enumerated()), id: \.offset) { _, todo in
                TodoRow(todo: todo)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }
}

private struct TodoRow: View {
    let todo: Todo

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: symbol)
                .foregroundStyle(todo.status == .inProgress ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            Text(todo.title)
                .scaledFont(.callout)
                .fontWeight(todo.status == .inProgress ? .medium : .regular)
                .foregroundStyle(todo.status == .completed ? .secondary : .primary)
                .strikethrough(todo.status == .completed)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .help(todo.title)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(todo.spokenLabel)
    }

    private var symbol: String {
        switch todo.status {
        case .pending: "circle"
        case .inProgress: "circle.inset.filled"
        case .completed: "checkmark.circle.fill"
        }
    }
}
