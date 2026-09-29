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
    /// Reads the facts from a Claude Code session log (JSONL).
    public static func claude(_ data: Data) -> SessionFacts {
        reading(data)
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

    fileprivate func nonEmpty(_ value: Any?) -> String? {
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

extension SessionFacts: ClaudeRowReader {
    public init() {
        self.init(model: nil)
    }

    /// Takes each value from the row when it has one, so the latest row wins; the first timestamp stays.
    mutating func read(_ row: [String: Any], number: Int) {
        if firstSeen == nil, let stamp = row["timestamp"] as? String {
            firstSeen = Self.parseTimestamp(stamp)
        }
        workingDirectory = nonEmpty(row["cwd"]) ?? workingDirectory
        gitBranch = nonEmpty(row["gitBranch"]) ?? gitBranch
        guard row["type"] as? String == "assistant", let message = row["message"] as? [String: Any] else { return }
        // Claude Code writes "<synthetic>" for replies it made up itself, such as an API error; they have no real usage.
        let model = nonEmpty(message["model"])
        guard model != "<synthetic>" else { return }
        self.model = model ?? self.model
        contextTokens = (message["usage"] as? [String: Any]).flatMap(Self.contextTokens) ?? contextTokens
    }
}
