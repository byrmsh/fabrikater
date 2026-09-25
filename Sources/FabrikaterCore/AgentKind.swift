/// The agent Herdr recognised in a pane, from the snapshot's `agent` field.
///
/// Herdr may report agents this app does not know yet; those decode as `.other` instead of failing.
public enum AgentKind: Hashable, Sendable {
    case claude
    case codex
    case pi
    case omp
    case opencode
    case grok
    case other(String)

    public init(rawValue: String) {
        switch rawValue {
        case "claude": self = .claude
        case "codex": self = .codex
        case "pi": self = .pi
        case "omp": self = .omp
        case "opencode": self = .opencode
        case "grok": self = .grok
        default: self = .other(rawValue)
        }
    }

    public var rawValue: String {
        switch self {
        case .claude: "claude"
        case .codex: "codex"
        case .pi: "pi"
        case .omp: "omp"
        case .opencode: "opencode"
        case .grok: "grok"
        case .other(let rawValue): rawValue
        }
    }
}

extension AgentKind: Codable {
    public init(from decoder: any Decoder) throws {
        self.init(rawValue: try decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
