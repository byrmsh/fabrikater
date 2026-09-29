import AppModel
import SwiftUI
import TranscriptKit

/// The Session Info panel: model, folder, branch, start and context use, from the session's log (B11).
struct SessionFactsView: View {
    let rows: [FactRow]

    var body: some View {
        Group {
            if rows.isEmpty {
                Text(SessionFacts.emptyMessage)
                    .foregroundStyle(.secondary)
            } else {
                Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 6) {
                    ForEach(rows) { row in
                        GridRow {
                            Text(row.label)
                                .foregroundStyle(.secondary)
                                .gridColumnAlignment(.trailing)
                            Text(row.value)
                                .fontDesign(.monospaced)
                                .lineLimit(2)
                                .truncationMode(.middle)
                        }
                    }
                }
            }
        }
        .font(.callout)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}
