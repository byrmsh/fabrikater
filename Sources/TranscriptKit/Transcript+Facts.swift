// B11: the model, folder, branch, start and context use of a session, read from its log's rows.

import Foundation

/// What a session's log says about the session itself. Each field is nil when no row in the part read carries it.
public struct SessionFacts: Equatable, Sendable {
    /// The model of the latest assistant reply, as the API names it (`claude-opus-4-1-20250805`).
    public var model: String?
    /// The working directory of the latest row that has one.
    public var workingDirectory: String?
    /// The git branch of the latest row that has one.
    public var gitBranch: String?
    /// The earliest timestamp in the part of the log that was read: the session's start unless the read was clipped.
    public var firstSeen: Date?
    /// Tokens the latest reply's prompt took: its input plus the cache tokens written and read.
    public var contextTokens: Int?

    public init(
        model: String? = nil,
        workingDirectory: String? = nil,
        gitBranch: String? = nil,
        firstSeen: Date? = nil,
        contextTokens: Int? = nil
    ) {
        self.model = model
        self.workingDirectory = workingDirectory
        self.gitBranch = gitBranch
        self.firstSeen = firstSeen
        self.contextTokens = contextTokens
    }

    public var isEmpty: Bool { self == SessionFacts() }
}

extension SessionFacts {
    /// Reads the facts from a Claude Code session log (JSONL). Scans from the end for the latest values and stops once
    /// it has them all, and from the start for the first timestamp, so a long log is not parsed twice over.
    public static func claude(_ data: Data) -> SessionFacts {
        let lines = data.split(separator: 0x0A)
        var facts = SessionFacts()
        for line in lines.reversed() {
            guard let row = ClaudeLog.row(line) else { continue }
            facts.takeLatest(from: row)
            if facts.hasEveryLatestValue { break }
        }
        for line in lines {
            if let stamp = ClaudeLog.row(line)?["timestamp"] as? String, let date = parseTimestamp(stamp) {
                facts.firstSeen = date
                break
            }
        }
        return facts
    }

    private var hasEveryLatestValue: Bool {
        model != nil && workingDirectory != nil && gitBranch != nil && contextTokens != nil
    }

    private mutating func takeLatest(from row: [String: Any]) {
        if workingDirectory == nil { workingDirectory = nonEmpty(row["cwd"]) }
        if gitBranch == nil { gitBranch = nonEmpty(row["gitBranch"]) }
        guard row["type"] as? String == "assistant", let message = row["message"] as? [String: Any] else { return }
        // Claude Code writes "<synthetic>" for replies it made up itself, such as an API error; they have no real usage.
        let model = nonEmpty(message["model"])
        guard model != "<synthetic>" else { return }
        if self.model == nil { self.model = model }
        if contextTokens == nil, let usage = message["usage"] as? [String: Any] {
            contextTokens = Self.contextTokens(usage)
        }
    }

    static func contextTokens(_ usage: [String: Any]) -> Int? {
        let keys = ["input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens"]
        let counts = keys.compactMap { usage[$0] as? Int }
        return counts.isEmpty ? nil : counts.reduce(0, +)
    }

    static func parseTimestamp(_ text: String) -> Date? {
        (try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(text))
            ?? (try? Date.ISO8601FormatStyle().parse(text))
    }

    private func nonEmpty(_ value: Any?) -> String? {
        guard let text = value as? String, !text.isEmpty else { return nil }
        return text
    }

    /// "84.2k tokens", "950 tokens", "1.2M tokens".
    public static func formatTokens(_ count: Int) -> String {
        func scaled(_ value: Double, _ unit: String) -> String {
            let rounded = (value * 10).rounded() / 10
            let text = rounded == rounded.rounded() ? String(Int(rounded)) : String(format: "%.1f", rounded)
            return "\(text)\(unit) tokens"
        }
        switch count {
        case ..<1000: return count == 1 ? "1 token" : "\(count) tokens"
        case ..<999_950: return scaled(Double(count) / 1000, "k")
        default: return scaled(Double(count) / 1_000_000, "M")
        }
    }
}
