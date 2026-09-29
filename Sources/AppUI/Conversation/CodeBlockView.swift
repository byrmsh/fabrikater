import AppModel
import SwiftUI

/// A fenced code block, highlighted for the language its fence names, scrolling sideways when a line is too long.
struct CodeBlockView: View {
    let language: String
    let text: String
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.findHighlight) private var findHighlight

    var body: some View {
        ScrollView(.horizontal) {
            Text(
                AttributedString(code: CodeLanguage.tokens(text, fence: language), dark: colorScheme == .dark)
                    .highlighting(findHighlight)
            )
            .scaledFont(.callout, design: .monospaced)
            .fixedSize()
            .padding(8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quinary, in: .rect(cornerRadius: 6))
    }
}
