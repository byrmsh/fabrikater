/// A conversation as the app shows it, from an agent's session log (docs/parsing.md section 2).
public struct Transcript: Equatable, Sendable {
    /// Oldest first.
    public var entries: [TranscriptEntry]
    /// True when the log is longer than what was read, so older history exists.
    public var isClipped: Bool
    /// The agent's current plan (`Transcript+Todos.swift`); empty when the session has none.
    public var todos: [Todo]
    /// What the log says about the session: model, folder, branch, start and context use (B11).
    public var facts: SessionFacts
    /// The files the session changed (`Transcript+Changes.swift`), in the order each was first touched.
    public var changes: [FileChange]

    public init(
        entries: [TranscriptEntry] = [],
        isClipped: Bool = false,
        todos: [Todo] = [],
        facts: SessionFacts = SessionFacts(),
        changes: [FileChange] = []
    ) {
        self.entries = entries
        self.isClipped = isClipped
        self.todos = todos
        self.facts = facts
        self.changes = changes
    }
}

public struct TranscriptEntry: Equatable, Sendable, Identifiable {
    public enum Role: String, Equatable, Sendable {
        case user
        case assistant
        /// A compaction summary the agent wrote about its own history.
        case summary
        /// Machine-injected content that still belongs on screen, such as a background task finishing.
        case note
    }

    /// Stable across reads of the same log: the row's `uuid`, or its line number when it has none.
    public var id: String
    /// ISO 8601, or empty when the log has none.
    public var timestamp: String
    public var role: Role
    public var parts: [TranscriptPart]

    public init(id: String, timestamp: String = "", role: Role, parts: [TranscriptPart]) {
        self.id = id
        self.timestamp = timestamp
        self.role = role
        self.parts = parts
    }
}

public enum TranscriptPart: Equatable, Sendable {
    case text(String, truncated: Bool = false)
    case tool(ToolCall)
}

public struct ToolCall: Equatable, Sendable {
    public var name: String
    /// One line describing the input: the command, the path, the pattern.
    public var summary: String
    /// Nil until the result row arrives, or when it fell outside the part of the log that was read.
    public var result: ToolResult?

    public init(name: String, summary: String, result: ToolResult? = nil) {
        self.name = name
        self.summary = summary
        self.result = result
    }
}

public struct ToolResult: Equatable, Sendable {
    public var text: String
    public var truncated: Bool
    public var isError: Bool

    public init(text: String, truncated: Bool = false, isError: Bool = false) {
        self.text = text
        self.truncated = truncated
        self.isError = isError
    }
}
