import AppModel
import SwiftUI

/// The find bar's query, while the entry being drawn holds a match; nil otherwise.
private struct FindHighlightKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

extension EnvironmentValues {
    var findHighlight: String? {
        get { self[FindHighlightKey.self] }
        set { self[FindHighlightKey.self] = newValue }
    }
}

extension AttributedString {
    /// This text with every occurrence of `query` marked as a find match, as Safari and Xcode mark theirs.
    func highlighting(_ query: String?) -> AttributedString {
        guard let query else { return self }
        let text = String(characters)
        var marked = self
        for range in ConversationFind.ranges(of: query, in: text) {
            let lower = marked.index(
                marked.startIndex, offsetByCharacters: text.distance(from: text.startIndex, to: range.lowerBound))
            let upper = marked.index(
                lower, offsetByCharacters: text.distance(from: range.lowerBound, to: range.upperBound))
            marked[lower..<upper].backgroundColor = .yellow
            marked[lower..<upper].foregroundColor = .black
        }
        return marked
    }
}
