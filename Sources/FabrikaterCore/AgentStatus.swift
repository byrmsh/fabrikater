/// Herdr's `agent_status` for a pane, tab or workspace.
///
/// `idle` and `done` both mean ready for input; `done` means finished and not yet seen.
/// `blocked` means Herdr recognised an approval or question dialog.
/// Values Herdr adds in later releases decode as `unknown`.
public enum AgentStatus: String, Hashable, Sendable, CaseIterable {
    case idle
    case working
    case blocked
    case done
    case unknown
}

extension AgentStatus: Codable {
    public init(from decoder: any Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        self = AgentStatus(rawValue: rawValue) ?? .unknown
    }
}
