import FabrikaterCore
import Foundation

/// The rows of a Claude Code session log (JSONL) that the transcript's features read.
enum ClaudeLog {
    /// The line as a JSON object, or nil when it does not parse (a clipped first line, a half-written last one) or is
    /// a subagent's row, whose tools, model and context are the subagent's rather than the session's.
    static func row(_ line: Data.SubSequence) -> [String: Any]? {
        guard let row = JSONLines.row(line) else { return nil }
        return row["isSidechain"] as? Bool == true ? nil : row
    }

    /// The row's `message.content` blocks, when it has them as a list.
    static func blocks(of row: [String: Any]) -> [[String: Any]]? {
        (row["message"] as? [String: Any])?["content"] as? [[String: Any]]
    }
}

/// One feature of the transcript read from a Claude log's rows, oldest first, one row at a time: the entries, the
/// plan, the facts, the changes. Subagent rows never reach it.
protocol ClaudeRowReader {
    init()
    /// Reads the next row; `number` is its line's number in the part of the log read.
    mutating func read(_ row: [String: Any], number: Int)
}

extension ClaudeRowReader {
    /// A reader that has read every row of the Claude log `data`.
    static func reading(_ data: Data) -> Self {
        var reader = Self()
        for (index, line) in data.split(separator: 0x0A, omittingEmptySubsequences: false).enumerated() {
            if let row = ClaudeLog.row(line) {
                reader.read(row, number: index + 1)
            }
        }
        return reader
    }
}

/// A Claude log's whole transcript: each line is decoded once and handed to every feature's reader. A new feature adds
/// its reader here and its value in `transcript`.
struct ClaudeLogReader: LogReader {
    private var entries = ClaudeTranscriptParser.Entries()
    private var plan = TodoReader()
    private var facts = SessionFacts()
    private var changes = ChangeReader()

    mutating func read(_ line: Data.SubSequence, number: Int) {
        guard let row = ClaudeLog.row(line) else { return }
        entries.read(row, number: number)
        plan.read(row, number: number)
        facts.read(row, number: number)
        changes.read(row, number: number)
    }

    var transcript: Transcript {
        Transcript(entries: entries.entries, todos: plan.todos, facts: facts, changes: changes.changes)
    }
}

extension Transcript {
    /// Everything the app shows from `data`, read as the last `window` bytes of a log in `format`. Todos, facts and
    /// changes are read from Claude logs only so far.
    public init(_ format: SessionLog.Format, data: Data, window: Int) {
        self = format.reader(reading: data).transcript
        isClipped = data.count >= window
    }

    /// Everything the app shows from the Claude log `data`, read as the last `window` bytes of the log.
    public init(claudeLog data: Data, window: Int) {
        self.init(.claude, data: data, window: window)
    }
}
