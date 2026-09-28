/// Collects entries in log order and folds each tool result onto the call it answers, which already sits in an
/// emitted entry, so results attach without reordering anything (docs/parsing.md 2.1, step 5).
struct TranscriptBuilder {
    private(set) var entries: [TranscriptEntry] = []
    /// Where each unanswered call sits, by its call id.
    private var pending: [String: (entry: Int, part: Int)] = [:]

    /// Adds `parts` as a new entry, or onto the last entry when `joiningLast` and that entry has the same role.
    /// `calls` names the call id of each tool part, by its index in `parts`.
    mutating func add(
        _ parts: [TranscriptPart], id: String, timestamp: String, role: TranscriptEntry.Role,
        calls: [Int: String] = [:], joiningLast: Bool = false
    ) {
        guard !parts.isEmpty else { return }
        let offset: Int
        if joiningLast, let last = entries.indices.last, entries[last].role == role {
            offset = entries[last].parts.count
            entries[last].parts.append(contentsOf: parts)
        } else {
            offset = 0
            entries.append(TranscriptEntry(id: id, timestamp: timestamp, role: role, parts: parts))
        }
        for (part, call) in calls {
            pending[call] = (entries.count - 1, offset + part)
        }
    }

    /// Attaches `result` to the call `callID` and returns true, or returns false when that call was not read.
    mutating func fold(_ result: ToolResult, into callID: String?) -> Bool {
        guard let callID, let (entry, part) = pending.removeValue(forKey: callID),
            case .tool(var call) = entries[entry].parts[part]
        else { return false }
        call.result = result
        entries[entry].parts[part] = .tool(call)
        return true
    }
}
