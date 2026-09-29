// Find in the conversation (⌘F): the loaded entries that hold the query, stepped through one entry at a time.

import Foundation
import TranscriptKit

/// A window's find bar over its conversation: what is searched for, which entries match and which one is current.
/// It searches every loaded entry's text and its tool calls' names and one-line summaries, ignoring case and
/// diacritics; tool results stay folded on screen, so they are not searched.
public struct ConversationFind: Equatable, Sendable {
    public private(set) var isShown = false
    public private(set) var query = ""
    /// The ids of the entries holding the query, oldest first.
    public private(set) var matches: [String] = []
    /// Grows each time Find is chosen, so the view focuses the field again even while the bar is already shown.
    public private(set) var focusRequests = 0
    /// The current match's place in `matches`.
    private var index: Int?

    public init() {}

    /// The entry the conversation scrolls to and marks as the current match.
    public var currentEntry: String? { index.map { matches[$0] } }

    /// What the conversation highlights: the query while the bar is shown and it matches something.
    public var highlight: String? { isShown && !matches.isEmpty ? query : nil }

    /// The count beside the field: "2 of 5" messages, "Not Found", or nothing before anything is typed.
    public var status: String? {
        guard !Self.isBlank(query) else { return nil }
        guard let index else { return "Not Found" }
        return "\(index + 1) of \(matches.count)"
    }

    /// True when the entry holds the query and the bar is shown, so the conversation shows it whole.
    public func reveals(_ entry: TranscriptEntry) -> Bool {
        highlight != nil && matches.contains(entry.id)
    }

    /// The query to highlight in `entry`, or nil when it holds no match or the bar is hidden.
    public func highlight(for entry: TranscriptEntry) -> String? {
        reveals(entry) ? highlight : nil
    }

    /// True when `entry` is the current match, which the conversation outlines.
    public func isCurrent(_ entry: TranscriptEntry) -> Bool {
        highlight != nil && currentEntry == entry.id
    }

    mutating func show() {
        isShown = true
        focusRequests += 1
    }

    /// Hides the bar and its highlights; the query stays for the next Find.
    mutating func hide() {
        isShown = false
    }

    /// Searches `entries` for `query` and makes the newest match current, since the conversation opens at its foot.
    mutating func search(_ query: String, in entries: [TranscriptEntry]) {
        self.query = query
        matches = Self.matches(of: query, in: entries)
        index = matches.indices.last
    }

    /// Searches again after the conversation changed, keeping the current match when it is still there.
    mutating func refresh(_ entries: [TranscriptEntry]) {
        let current = currentEntry
        matches = Self.matches(of: query, in: entries)
        index = current.flatMap { matches.firstIndex(of: $0) } ?? matches.indices.last
    }

    /// Moves to the next match (`offset` 1) or the previous one (-1), wrapping around at either end, and shows the bar
    /// again if it was hidden.
    mutating func step(_ offset: Int) {
        guard let index, !matches.isEmpty else { return }
        isShown = true
        self.index = (index + offset + matches.count) % matches.count
    }

    /// The ids of the entries in `entries` that hold `query`, in order.
    static func matches(of query: String, in entries: [TranscriptEntry]) -> [String] {
        guard !isBlank(query) else { return [] }
        return entries.filter { entry in
            entry.searchableTexts.contains { $0.range(of: query, options: options) != nil }
        }.map(\.id)
    }

    /// Where `query` occurs in `text`, ignoring case and diacritics, first to last and never overlapping.
    public static func ranges(of query: String, in text: String) -> [Range<String.Index>] {
        guard !isBlank(query) else { return [] }
        var found: [Range<String.Index>] = []
        var start = text.startIndex
        while start < text.endIndex,
            let range = text.range(of: query, options: options, range: start..<text.endIndex)
        {
            found.append(range)
            start = range.upperBound
        }
        return found
    }

    private static let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

    private static func isBlank(_ query: String) -> Bool {
        query.allSatisfy(\.isWhitespace)
    }
}

extension TranscriptEntry {
    /// The texts the conversation shows for this entry with its tool calls folded: messages, tool names and summaries.
    fileprivate var searchableTexts: [String] {
        parts.flatMap { part -> [String] in
            switch part {
            case .text(let text, _): [text]
            case .tool(let call): [call.name, call.summary]
            }
        }
    }
}
