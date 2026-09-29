import AppModel
import SwiftUI

/// A message's markdown, laid out block by block from `MarkdownBlock.parse`.
struct MarkdownView: View {
    let blocks: [MarkdownBlock]
    @Environment(\.findHighlight) private var findHighlight

    init(_ text: String) {
        blocks = MarkdownBlock.parse(text)
    }

    init(blocks: [MarkdownBlock]) {
        self.blocks = blocks
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                view(for: block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func inline(_ text: String) -> AttributedString {
        AttributedString(inlineMarkdown: text).highlighting(findHighlight)
    }

    @ViewBuilder
    private func view(for block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            Text(inline(text))
                .scaledFont(level == 1 ? .title2 : level == 2 ? .title3 : .body)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 4)
        case .paragraph(let text):
            Text(inline(text))
        case .list(let items):
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(item.marker)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 14, alignment: .trailing)
                        Text(inline(item.text))
                    }
                    .padding(.leading, CGFloat(item.level) * 18)
                }
            }
        case .code(let language, let text):
            CodeBlockView(language: language, text: text)
        case .quote(let inner):
            MarkdownView(blocks: inner)
                .foregroundStyle(.secondary)
                .padding(.leading, 12)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(.quaternary)
                        .frame(width: 3)
                }
        case .table(let table):
            MarkdownTableView(table: table)
        case .rule:
            Divider()
        }
    }
}

/// A markdown table as a grid, header row bold, each column aligned as its delimiter row says.
private struct MarkdownTableView: View {
    let table: MarkdownTable
    @Environment(\.findHighlight) private var findHighlight

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 5) {
            GridRow {
                ForEach(Array(table.header.enumerated()), id: \.offset) { column, cell in
                    Text(AttributedString(inlineMarkdown: cell).highlighting(findHighlight))
                        .fontWeight(.semibold)
                        .gridColumnAlignment(alignment(column))
                }
            }
            Divider()
                .gridCellUnsizedAxes(.horizontal)
            ForEach(Array(table.rows.enumerated()), id: \.offset) { _, row in
                GridRow {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                        Text(AttributedString(inlineMarkdown: cell).highlighting(findHighlight))
                    }
                }
            }
        }
        .padding(8)
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.quaternary))
    }

    private func alignment(_ column: Int) -> HorizontalAlignment {
        switch table.alignments[column] {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }
}

extension AttributedString {
    /// `text` with its inline markdown (emphasis, inline code, links) styled and its line breaks kept.
    init(inlineMarkdown text: String) {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        self = (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}
