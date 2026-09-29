// Ported from AltanS/collie@b7ddc17 bridge/journal/claude.ts (MIT)

import Foundation

/// Parses a Claude Code session log (JSONL) into transcript entries (docs/parsing.md 2.1).
///
/// Differences from Collie, as parsing.md recommends: `isMeta` rows are dropped, and consecutive assistant rows of
/// one API response (same `message.id`) become one entry. Thinking blocks are dropped, since the design hides them.
public enum ClaudeTranscriptParser {
    public static func parse(_ data: Data) -> [TranscriptEntry] {
        Entries.reading(data).entries
    }

    /// The entries, grown row by row.
    struct Entries: ClaudeRowReader {
        private(set) var entries: [TranscriptEntry] = []
        /// Where each unanswered `tool_use` sits, so its result can fold onto it.
        private var pendingTools: [String: (entry: Int, part: Int)] = [:]
        /// The `message.id` of the last entry, when it is an assistant entry.
        private var lastAssistantMessageID: String?

        mutating func read(_ row: [String: Any], number lineNumber: Int) {
            let type = row["type"] as? String
            guard type == "user" || type == "assistant", row["isMeta"] as? Bool != true else { return }
            guard let message = row["message"] as? [String: Any] else { return }

            let id = (row["uuid"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "line-\(lineNumber)"
            let timestamp = row["timestamp"] as? String ?? ""
            let isAssistant = type == "assistant"
            var role: TranscriptEntry.Role = isAssistant ? .assistant : .user
            var parts: [TranscriptPart] = []
            var tools: [(id: String, part: Int)] = []

            if let content = message["content"] as? String {
                guard let (classified, text) = classifyUserText(content) else { return }
                role = classified
                parts.append(.text(text))
            } else if let blocks = message["content"] as? [[String: Any]] {
                for block in blocks {
                    switch block["type"] as? String {
                    case "text":
                        if let text = block["text"] as? String, !TextRules.isBlank(text) {
                            let (clamped, truncated) = TextRules.clamp(
                                TextRules.stripANSI(text), to: TextRules.textLimit)
                            parts.append(.text(clamped, truncated: truncated))
                        }
                    case "tool_use":
                        let call = ToolCall(
                            name: block["name"] as? String ?? "tool",
                            summary: TextRules.summarizeToolInput(block["input"])
                        )
                        if let toolID = block["id"] as? String {
                            tools.append((toolID, parts.count))
                        }
                        parts.append(.tool(call))
                    case "tool_result":
                        if let orphan = foldResult(block) {
                            parts.append(.tool(orphan))
                        }
                    default:
                        continue
                    }
                }
            }
            guard !parts.isEmpty else { return }
            if row["isCompactSummary"] as? Bool == true {
                role = .summary
            }

            let messageID = isAssistant ? message["id"] as? String : nil
            let entryIndex: Int
            let partOffset: Int
            if role == .assistant, let messageID, messageID == lastAssistantMessageID, let last = entries.indices.last {
                entryIndex = last
                partOffset = entries[last].parts.count
                entries[last].parts.append(contentsOf: parts)
            } else {
                entryIndex = entries.count
                partOffset = 0
                entries.append(TranscriptEntry(id: id, timestamp: timestamp, role: role, parts: parts))
            }
            lastAssistantMessageID = role == .assistant ? messageID : nil
            for tool in tools {
                pendingTools[tool.id] = (entryIndex, partOffset + tool.part)
            }
        }

        /// Attaches a result to its call and returns nil, or returns an orphan part when the call was not read.
        private mutating func foldResult(_ block: [String: Any]) -> ToolCall? {
            let raw: String
            if let text = block["content"] as? String {
                raw = text
            } else if let items = block["content"] as? [[String: Any]] {
                raw = items.compactMap { $0["type"] as? String == "text" ? $0["text"] as? String : nil }
                    .joined(separator: "\n")
            } else {
                raw = ""
            }
            let (text, truncated) = TextRules.clamp(TextRules.stripANSI(raw), to: TextRules.resultLimit)
            let result = ToolResult(text: text, truncated: truncated, isError: block["is_error"] as? Bool == true)
            if let toolID = block["tool_use_id"] as? String,
                let (entry, part) = pendingTools.removeValue(forKey: toolID),
                case .tool(var call) = entries[entry].parts[part]
            {
                call.result = result
                entries[entry].parts[part] = .tool(call)
                return nil
            }
            return TextRules.isBlank(text) ? nil : ToolCall(name: "result", summary: "", result: result)
        }
    }

    /// Classifies a string `content`: a human turn, a note, or plumbing to drop (nil).
    static func classifyUserText(_ raw: String) -> (TranscriptEntry.Role, String)? {
        let text = TextRules.stripANSI(raw)
        let start = text.drop { $0.isWhitespace }
        func inner(_ tag: String) -> String? {
            guard let open = text.range(of: "<\(tag)>") else { return nil }
            let rest = text[open.upperBound...]
            let end = rest.range(of: "</\(tag)>")?.lowerBound ?? rest.endIndex
            return rest[..<end].trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if start.hasPrefix("<system-reminder>") || start.hasPrefix("<local-command-caveat>") {
            return nil
        }
        if start.hasPrefix("<command-name>") {
            let command = [inner("command-name"), inner("command-args")].compactMap(\.self).joined(separator: " ")
            let trimmed = command.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? nil : (.user, trimmed)
        }
        if start.hasPrefix("<local-command-stdout>") {
            guard let output = inner("local-command-stdout"), !output.isEmpty else { return nil }
            return (.note, output)
        }
        if start.hasPrefix("<task-notification>") {
            guard let summary = inner("summary"), !summary.isEmpty else { return nil }
            return (.note, summary)
        }
        guard !TextRules.isBlank(text) else { return nil }
        let (clamped, _) = TextRules.clamp(text, to: TextRules.textLimit)
        return (.user, clamped)
    }
}
