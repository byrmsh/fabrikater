import FabrikaterCore
import Foundation

/// The rows of a Claude Code session log (JSONL) that the transcript's features read.
enum ClaudeLog {
    /// The line as a JSON object, or nil when it does not parse (a clipped first line, a half-written last one) or is
    /// a subagent's row, whose tools, model and context are the subagent's rather than the session's.
    static func row(_ line: Data.SubSequence) -> [String: Any]? {
        guard let row = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { return nil }
        return row["isSidechain"] as? Bool == true ? nil : row
    }

    /// The row's `message.content` blocks, when it has them as a list.
    static func blocks(of row: [String: Any]) -> [[String: Any]]? {
        (row["message"] as? [String: Any])?["content"] as? [[String: Any]]
    }
}

extension Transcript {
    /// Everything the app shows from `data`, read as the last `window` bytes of a log in `format`. Todos, facts and
    /// changes are read from Claude logs only so far.
    public init(_ format: SessionLog.Format, data: Data, window: Int) {
        switch format {
        case .claude: self.init(claudeLog: data, window: window)
        case .codex: self.init(entries: CodexTranscriptParser.parse(data), isClipped: data.count >= window)
        case .pi: self.init(entries: PiTranscriptParser.parse(data), isClipped: data.count >= window)
        case .opencode: self.init(entries: OpenCodeTranscriptParser.parse(data), isClipped: data.count >= window)
        }
    }

    /// Everything the app shows from the Claude log `data`, read as the last `window` bytes of the log.
    public init(claudeLog data: Data, window: Int) {
        self.init(
            entries: ClaudeTranscriptParser.parse(data), isClipped: data.count >= window,
            todos: Self.latestTodos(inClaudeLog: data), facts: SessionFacts.claude(data),
            changes: Self.changes(inClaudeLog: data))
    }
}
