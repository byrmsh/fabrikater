// Ported from AltanS/collie@b7ddc17 bridge/journal/opencode.ts (MIT)

import Foundation

/// Parses the JSON lines `HostCommand.openCodeRows` prints for an OpenCode session, one per message, into transcript
/// entries (docs/parsing.md 2.4).
///
/// A V1 line is `{id, ts, data, parts: [{id, data}]}`, with the role in `data.role`; a V2 line is `{id, ts, type, data}`,
/// with the role in `type` and the parts inline in `data.content`. A message printed again, because it changed while
/// followed, replaces its earlier entry in place. Reasoning is dropped, as the design hides thinking.
public enum OpenCodeTranscriptParser {
    public static func parse(_ data: Data) -> [TranscriptEntry] {
        Reader.reading(data).transcript.entries
    }

    struct Reader: LogReader {
        private var entries: [TranscriptEntry] = []
        private var positions: [String: Int] = [:]

        var transcript: Transcript { Transcript(entries: entries) }

        mutating func read(_ line: Data.SubSequence, number: Int) {
            guard let row = JSONLines.row(line) else { return }
            let record = row["data"] as? [String: Any] ?? [:]
            let id = (row["id"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "line-\(number)"
            let entry: TranscriptEntry? =
                if let type = row["type"] as? String {
                    role(of: type).flatMap { role in
                        entry(id: id, row: row, record: record, role: role, parts: inlineParts(of: record))
                    }
                } else {
                    role(of: record["role"] as? String).flatMap { role in
                        let parts = (row["parts"] as? [[String: Any]] ?? []).compactMap { $0["data"] as? [String: Any] }
                        return entry(id: id, row: row, record: record, role: role, parts: parts)
                    }
                }
            if let position = positions[id] {
                if let entry {
                    entries[position] = entry
                }
            } else if let entry {
                positions[id] = entries.count
                entries.append(entry)
            }
        }
    }

    private static func entry(
        id: String, row: [String: Any], record: [String: Any], role: TranscriptEntry.Role, parts: [[String: Any]]
    ) -> TranscriptEntry? {
        let rendered = parts.compactMap(part)
        guard !rendered.isEmpty else { return nil }
        let created = (record["time"] as? [String: Any])?["created"] as? Double ?? row["ts"] as? Double
        return TranscriptEntry(
            id: id, timestamp: created.map(isoTimestamp(milliseconds:)) ?? "", role: role, parts: rendered)
    }

    /// `user` and `assistant` speak and a V2 `compaction` is a summary; anything else (V2's `system`, `synthetic`,
    /// `idle`, the switches) is plumbing.
    private static func role(of type: String?) -> TranscriptEntry.Role? {
        switch type {
        case "user": .user
        case "assistant": .assistant
        case "compaction", "summary": .summary
        default: nil
        }
    }

    /// A V2 message's parts: `content` when it has any, else its one text (`text` for a user, `summary` for a
    /// compaction, `error.message` for a failed turn).
    private static func inlineParts(of record: [String: Any]) -> [[String: Any]] {
        if let content = record["content"] as? [[String: Any]], !content.isEmpty { return content }
        let text =
            record["text"] as? String ?? record["summary"] as? String
            ?? (record["error"] as? [String: Any])?["message"] as? String ?? ""
        return text.isEmpty ? [] : [["type": "text", "text": text]]
    }

    /// A part as the transcript shows it; nil for reasoning, `step-start`, `step-finish` and anything unknown.
    static func part(_ data: [String: Any]) -> TranscriptPart? {
        switch data["type"] as? String {
        case "text":
            return (data["text"] as? String).flatMap(TextRules.textPart)
        case "tool":
            let state = data["state"] as? [String: Any] ?? [:]
            // V1 names the tool `tool`, V2 `name`.
            let name = data["tool"] as? String ?? data["name"] as? String ?? "tool"
            var call = ToolCall(name: name, summary: TextRules.summarizeToolInput(state["input"]))
            switch state["status"] as? String {
            case "completed":
                let output = outputText(state)
                if !output.isEmpty {
                    call.result = TextRules.result(output)
                }
            case "error":
                let error =
                    state["error"] as? String ?? (state["error"] as? [String: Any])?["message"] as? String
                    ?? outputText(state)
                call.result = TextRules.result(error, isError: true)
            default:
                break
            }
            return .tool(call)
        default:
            return nil
        }
    }

    /// V1 writes `state.output`; V2 writes `state.content`, a list of text items.
    private static func outputText(_ state: [String: Any]) -> String {
        if let output = state["output"] as? String { return output }
        let items = state["content"] as? [[String: Any]] ?? []
        return items.compactMap { $0["text"] as? String }.joined(separator: "\n")
    }

    private static func isoTimestamp(milliseconds: Double) -> String {
        Date.ISO8601FormatStyle(includingFractionalSeconds: true).format(
            Date(timeIntervalSince1970: milliseconds / 1000))
    }
}
