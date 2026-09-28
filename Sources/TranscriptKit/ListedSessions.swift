import FabrikaterCore

/// How one agent's Past Sessions listing (`HostCommand.sessions`) names its sessions and where a listed row keeps the
/// session's prompt. An agent is added here with one case.
struct ListedSessions {
    /// The session id in a listed log's name, or nil when the name is not one of the agent's logs.
    let session: (String) -> SessionID?
    /// The prompt a whole row carries.
    let prompt: ([String: Any]) -> String?
    /// The keys a row cut short by the listing is read after, in order.
    let cutKeys: [String]

    init(_ format: SessionLog.Format) {
        switch format {
        case .claude:
            // `<uuid>.jsonl`
            session = Self.id(endingName:)
            prompt = Self.messageText
            cutKeys = ["content", "text"]
        case .pi:
            // `<ts>_<uuid>.jsonl`, written by pi and omp.
            session = Self.id(endingName:)
            prompt = Self.messageText
            cutKeys = ["text", "content"]
        case .codex:
            // `rollout-<ts>-<uuid>.jsonl`; a `user_message` event carries the prompt as typed, a user message item in
            // `input_text` blocks.
            session = Self.id(endingName:)
            prompt = { row in
                let payload = row["payload"] as? [String: Any]
                return payload?["message"] as? String ?? Self.firstText(payload?["content"])
            }
            cutKeys = ["message", "text"]
        case .opencode:
            // The session id itself, with a JSON object holding the title OpenCode gave the session.
            session = { SessionID($0) }
            prompt = { $0["title"] as? String }
            cutKeys = ["title"]
        }
    }

    /// The UUID that ends a `.jsonl` log's name.
    private static func id(endingName name: String) -> SessionID? {
        guard name.hasSuffix(".jsonl") else { return nil }
        return SessionID(String(name.dropLast(6).suffix(36)))
    }

    /// A Claude or pi row's `message.content`: a string, or its first text block.
    private static func messageText(_ row: [String: Any]) -> String? {
        let content = (row["message"] as? [String: Any])?["content"]
        return content as? String ?? firstText(content)
    }

    /// The `text` of the first block in `content` that has one.
    private static func firstText(_ content: Any?) -> String? {
        (content as? [[String: Any]])?.lazy.compactMap { block -> String? in
            guard let type = block["type"] as? String, type == "text" || type == "input_text" else { return nil }
            return block["text"] as? String
        }.first
    }
}
