// Ported from AltanS/collie@b7ddc17 bridge/journal/codex.ts (MIT)

import Foundation

/// Parses a Codex rollout log (JSONL) into transcript entries (docs/parsing.md 2.2).
///
/// Codex writes every turn twice, as `response_item` and as `event_msg`; only `response_item` carries tool output, so
/// it is the only family read. Differences from Collie: reasoning is dropped, as the design hides thinking; a tool call
/// joins the assistant entry before it, so a reply and the calls it makes read as one message, as Claude's do; and
/// `custom_tool_call` rows (`apply_patch`) are read like function calls.
public enum CodexTranscriptParser {
    public static func parse(_ data: Data) -> [TranscriptEntry] {
        var builder = TranscriptBuilder()
        var ids = JSONLines.RowIDs()
        for (line, _, row) in JSONLines.rows(in: data) {
            guard row["type"] as? String == "response_item", let payload = row["payload"] as? [String: Any] else {
                continue
            }
            // Every response_item advances the ids, rendered or not, so ids depend on the window alone.
            let id = ids.next(for: line, prefix: "cx")
            let timestamp = row["timestamp"] as? String ?? ""
            switch payload["type"] as? String {
            case "message":
                guard let role = speaker(payload["role"]), let part = TextRules.textPart(text(of: payload["content"]))
                else { continue }
                if role == .user, case .text(let text, _) = part, isInjectedContext(text) { continue }
                builder.add([part], id: id, timestamp: timestamp, role: role)
            case "function_call", "custom_tool_call":
                let name = payload["name"] as? String ?? "tool"
                let summary = name == "apply_patch" ? patchSummary(payload) : argumentSummary(payload["arguments"])
                let calls = (payload["call_id"] as? String).map { [0: $0] } ?? [:]
                builder.add(
                    [.tool(ToolCall(name: name, summary: summary))], id: id, timestamp: timestamp, role: .assistant,
                    calls: calls, joiningLast: true)
            case "function_call_output", "custom_tool_call_output":
                let result = TextRules.result(output(payload["output"]))
                guard !builder.fold(result, into: payload["call_id"] as? String), !TextRules.isBlank(result.text)
                else { continue }
                builder.add(
                    [.tool(ToolCall(name: "result", summary: "", result: result))], id: id, timestamp: timestamp,
                    role: .assistant, joiningLast: true)
            default:
                continue
            }
        }
        return builder.entries
    }

    /// User and assistant speak; `developer` rows carry injected system prompts and anything else is plumbing.
    private static func speaker(_ role: Any?) -> TranscriptEntry.Role? {
        switch role as? String {
        case "user": .user
        case "assistant": .assistant
        default: nil
        }
    }

    /// The text blocks of a message (`input_text`, `output_text`), one per line.
    private static func text(of content: Any?) -> String {
        if let text = content as? String { return text }
        let blocks = content as? [[String: Any]] ?? []
        return blocks.compactMap { $0["text"] as? String }.filter { !$0.isEmpty }.joined(separator: "\n")
    }

    /// Context Codex sends as a user turn that the user never typed.
    private static func isInjectedContext(_ text: String) -> Bool {
        text.drop { $0.isWhitespace }.hasPrefix("<environment_context>")
    }

    /// `arguments` is a JSON string: summarised as an object, or as one line when it does not parse.
    private static func argumentSummary(_ arguments: Any?) -> String {
        guard let raw = arguments as? String else { return TextRules.summarizeToolInput(arguments) }
        guard let parsed = try? JSONSerialization.jsonObject(with: Data(raw.utf8)) else {
            return TextRules.oneLine(raw)
        }
        return TextRules.summarizeToolInput(parsed)
    }

    /// The files an `apply_patch` touches, from its `*** Add File:`, `*** Update File:` and `*** Delete File:` lines.
    private static func patchSummary(_ payload: [String: Any]) -> String {
        let patch = payload["input"] as? String ?? (payload["arguments"] as? String) ?? ""
        let prefixes = ["*** Add File: ", "*** Update File: ", "*** Delete File: "]
        let paths = patch.split(separator: "\n").compactMap { line in
            prefixes.first { line.hasPrefix($0) }.map { line.dropFirst($0.count) }
        }
        return paths.isEmpty ? TextRules.oneLine(patch) : TextRules.oneLine(paths.joined(separator: " "))
    }

    /// `output` is a JSON string wrapping `{"output": "…"}`; anything else is the output itself.
    static func output(_ raw: Any?) -> String {
        guard let raw = raw as? String else { return "" }
        if let wrapper = try? JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any],
            let output = wrapper["output"] as? String
        {
            return output
        }
        return raw
    }
}
