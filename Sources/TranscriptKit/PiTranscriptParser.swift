// Ported from AltanS/collie@b7ddc17 bridge/journal/pi.ts (MIT)

import Foundation

/// Parses a pi or omp session log (JSONL) into transcript entries (docs/parsing.md 2.3).
///
/// Differences from Collie: thinking is dropped, as the design hides it, and so are images, which the transcript model
/// does not carry yet.
public enum PiTranscriptParser {
    public static func parse(_ data: Data) -> [TranscriptEntry] {
        var builder = TranscriptBuilder()
        for (_, number, row) in JSONLines.rows(in: data) {
            guard row["type"] as? String == "message", let message = row["message"] as? [String: Any] else { continue }
            let id = (row["id"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "line-\(number)"
            let timestamp = row["timestamp"] as? String ?? ""
            let blocks = message["content"] as? [[String: Any]] ?? []

            if message["role"] as? String == "toolResult" {
                let text = blocks.compactMap { $0["type"] as? String == "text" ? $0["text"] as? String : nil }
                    .joined(separator: "\n")
                let result = TextRules.result(text, isError: message["isError"] as? Bool == true)
                guard !builder.fold(result, into: message["toolCallId"] as? String), !TextRules.isBlank(result.text)
                else { continue }
                let name = message["toolName"] as? String ?? "result"
                builder.add(
                    [.tool(ToolCall(name: name, summary: "", result: result))], id: id, timestamp: timestamp,
                    role: .assistant)
                continue
            }

            var parts: [TranscriptPart] = []
            var calls: [Int: String] = [:]
            for block in blocks {
                switch block["type"] as? String {
                case "text":
                    if let part = (block["text"] as? String).flatMap(TextRules.textPart) {
                        parts.append(part)
                    }
                case "toolCall":
                    if let call = block["id"] as? String {
                        calls[parts.count] = call
                    }
                    // pi passes `arguments` as an object, unlike Codex's JSON string.
                    let name = block["name"] as? String ?? "tool"
                    parts.append(.tool(ToolCall(name: name, summary: TextRules.summarizeToolInput(block["arguments"]))))
                default:
                    continue
                }
            }
            let role: TranscriptEntry.Role = message["role"] as? String == "assistant" ? .assistant : .user
            builder.add(parts, id: id, timestamp: timestamp, role: role, calls: calls)
        }
        return builder.entries
    }
}
