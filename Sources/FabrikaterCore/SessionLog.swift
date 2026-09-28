/// Where an agent's conversation is kept on the host: which log format, and the session in it (docs/parsing.md 1.2).
/// OpenCode keeps no file per session; its rows are printed as a log of the same kind.
public struct SessionLog: Hashable, Sendable, Codable, CustomStringConvertible {
    /// A log layout and grammar. Agents that share one (pi and omp) share a format.
    public enum Format: String, CaseIterable, Codable, Sendable {
        case claude
        case codex
        case pi
        /// Not a file: rows of OpenCode's SQLite database, printed one JSON line per message.
        case opencode

        /// The format `agent` writes, or nil when this version has no parser for it. Matched by exact agent, never by
        /// prefix; omp is an alias of pi (docs/parsing.md 1.1).
        public init?(agent: AgentKind) {
            switch agent {
            case .claude: self = .claude
            case .codex: self = .codex
            case .pi, .omp: self = .pi
            case .opencode: self = .opencode
            case .grok, .other: return nil
            }
        }
    }

    public let format: Format
    public let session: SessionID

    public init(format: Format, session: SessionID) {
        self.format = format
        self.session = session
    }

    /// Nil when `agent` has no parser.
    public init?(agent: AgentKind, session: SessionID) {
        guard let format = Format(agent: agent) else { return nil }
        self.init(format: format, session: session)
    }

    public var description: String { "\(format.rawValue):\(session)" }
}
