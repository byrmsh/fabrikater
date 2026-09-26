import FabrikaterCore
import Foundation
import HerdrKit

// B3: ⌘K opens a sheet that jumps to any pane, ranked by a fuzzy match on its name, workspace, tab and agent.

/// One pane in the switcher: its sidebar row (with its local name) and where it lives.
public struct SwitcherItem: Equatable, Sendable, Identifiable {
    public var row: PaneRow
    /// "Workspace › Tab", as in the pane header.
    public var location: String
    public var agent: String

    public var id: PaneID { row.id }

    /// What VoiceOver reads for the result: the name, where it lives and its status.
    public var accessibilityLabel: String {
        [row.label, location, row.status.title].filter { !$0.isEmpty }.joined(separator: ", ")
    }

    /// The text the query matches against, name first so a match on the name ranks highest.
    var searchText: String { [row.label, location, agent].joined(separator: " ") }
}

/// The open switcher: the query, its ranked results and the highlighted result that Return chooses.
public struct QuickSwitcher: Equatable, Sendable {
    public private(set) var query = ""
    public private(set) var results: [SwitcherItem]
    public private(set) var highlighted: PaneID?
    private var items: [SwitcherItem]

    /// What the sheet says in place of the list when nothing matches.
    public var emptyMessage: String? {
        guard results.isEmpty else { return nil }
        return items.isEmpty ? "No Panes" : "No Matching Panes"
    }

    init(items: [SwitcherItem]) {
        self.items = items
        results = items
        highlighted = items.first?.id
    }

    func searching(_ query: String) -> QuickSwitcher {
        var switcher = self
        switcher.query = query
        switcher.results = Self.rank(query: query, panes: items)
        switcher.highlighted = switcher.results.first?.id
        return switcher
    }

    /// The switcher over a new herd's panes, keeping the query and, while it is still a result, the highlight.
    func refreshing(_ items: [SwitcherItem]) -> QuickSwitcher {
        var switcher = self
        switcher.items = items
        switcher.results = Self.rank(query: query, panes: items)
        if !switcher.results.contains(where: { $0.id == highlighted }) {
            switcher.highlighted = switcher.results.first?.id
        }
        return switcher
    }

    /// The highlight moved `offset` results down, stopping at either end.
    func moving(by offset: Int) -> QuickSwitcher {
        guard !results.isEmpty else { return self }
        let index = results.firstIndex { $0.id == highlighted } ?? 0
        var switcher = self
        switcher.highlighted = results[min(max(index + offset, 0), results.count - 1)].id
        return switcher
    }

    /// The panes whose text contains the query as a subsequence, best first; ties keep sidebar order.
    /// An empty query lists every pane.
    static func rank(query: String, panes: [SwitcherItem]) -> [SwitcherItem] {
        let needle = query.filter { !$0.isWhitespace }.map { $0.lowercased() }
        guard !needle.isEmpty else { return panes }
        return panes.enumerated()
            .compactMap { index, item in score(needle, in: item.searchText).map { (item, $0, index) } }
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.2 < $1.2 }
            .map(\.0)
    }

    /// A subsequence match's score, or nil when `needle` is not a subsequence of `text`: a point per
    /// character, more for a character that starts a word or follows the previous match, and more again
    /// when the match starts the text. Tries every start of the first character and keeps the best.
    static func score(_ needle: [String], in text: String) -> Int? {
        let original = Array(text)
        let haystack = original.map { $0.lowercased() }
        guard let first = needle.first else { return 0 }
        return haystack.indices.filter { haystack[$0] == first }
            .compactMap { start -> Int? in
                var total = 0
                var position = start
                var previous: Int?
                for character in needle {
                    guard let index = haystack[position...].firstIndex(of: character) else { return nil }
                    total += 1
                    if isWordStart(index, in: original) { total += 3 }
                    if let previous, index == previous + 1 { total += 2 }
                    previous = index
                    position = index + 1
                }
                return total + (start == 0 ? 5 : 0)
            }
            .max()
    }

    private static func isWordStart(_ index: Int, in text: [Character]) -> Bool {
        guard index > 0 else { return true }
        let previous = text[index - 1]
        let character = text[index]
        if !(previous.isLetter || previous.isNumber) { return true }
        return previous.isLowercase && character.isUppercase
    }
}

extension [SidebarSection] {
    /// Every pane in sidebar order, with its location and agent from the herd.
    func switcherItems(in herd: Herd) -> [SwitcherItem] {
        flatMap { $0.rows.flatMap(\.panes) }.map { row in
            let pane = herd.pane(row.id)
            return SwitcherItem(
                row: row, location: pane.map(herd.location(of:)) ?? "", agent: row.agent?.title ?? "Shell")
        }
    }
}
