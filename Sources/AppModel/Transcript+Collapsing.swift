// B8: long compaction summaries and user prompts show their first lines until expanded.

import TranscriptKit

/// How long an entry may run before it starts collapsed, and how much of it a collapsed entry shows.
public enum Collapsing {
    /// A collapsed entry shows this many lines, and a summary longer than this starts collapsed.
    public static let visibleLines = 4
    /// A user prompt longer than this many lines starts collapsed.
    public static let promptLines = 12
    /// Characters a line holds in the conversation before it wraps, so one long pasted line still counts as several.
    static let wrapWidth = 100

    /// Roughly how many lines `text` takes on screen: each line of the text, plus one for every `wrapWidth` it wraps.
    static func lineCount(_ text: String) -> Int {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .reduce(0) { $0 + max(1, ($1.count + wrapWidth - 1) / wrapWidth) }
    }
}

extension TranscriptEntry {
    /// True when the entry is long enough to start collapsed and offer Show All.
    public var isCollapsible: Bool {
        let lines = parts.reduce(0) { total, part in
            guard case .text(let text, _) = part else { return total }
            return total + Collapsing.lineCount(text)
        }
        switch role {
        case .summary: return lines > Collapsing.visibleLines
        case .user: return lines > Collapsing.promptLines
        case .assistant, .note: return false
        }
    }
}

/// The entries the user expanded in the conversation on screen. Kept per pane while it is shown, never saved.
public struct EntryExpansion: Equatable, Sendable {
    private var expanded: Set<String> = []

    public init() {}

    /// True when `entry` shows only its first `Collapsing.visibleLines` lines.
    public func isCollapsed(_ entry: TranscriptEntry) -> Bool {
        entry.isCollapsible && !expanded.contains(entry.id)
    }

    /// What the entry's Show All or Show Less button runs, or nil when the entry is too short to collapse.
    public func toggle(for entry: TranscriptEntry) -> AppCommand? {
        guard entry.isCollapsible else { return nil }
        return isCollapsed(entry) ? .expandEntry(entry.id) : .collapseEntry(entry.id)
    }

    public func expanding(_ id: String) -> EntryExpansion {
        var copy = self
        copy.expanded.insert(id)
        return copy
    }

    public func collapsing(_ id: String) -> EntryExpansion {
        var copy = self
        copy.expanded.remove(id)
        return copy
    }
}
