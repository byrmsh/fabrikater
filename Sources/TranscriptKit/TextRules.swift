// Ported from AltanS/collie@b7ddc17 bridge/journal/text.ts (MIT)

import Foundation

/// The text rules every parser shares (docs/parsing.md section 2).
enum TextRules {
    static let textLimit = 20_000
    static let resultLimit = 2_000
    static let summaryLimit = 200
    /// The input keys a tool summary is taken from, in order of preference.
    static let summaryKeys = [
        "file_path", "command", "pattern", "query", "url", "path", "description", "task", "prompt",
    ]

    static func isBlank(_ text: String) -> Bool {
        text.allSatisfy(\.isWhitespace)
    }

    /// Stripped of ANSI and clamped to the text limit, or nil when blank.
    static func textPart(_ raw: String) -> TranscriptPart? {
        let text = stripANSI(raw)
        guard !isBlank(text) else { return nil }
        let (clamped, truncated) = clamp(text, to: textLimit)
        return .text(clamped, truncated: truncated)
    }

    /// A tool's output, stripped of ANSI and clamped to the result limit.
    static func result(_ raw: String, isError: Bool = false) -> ToolResult {
        let (text, truncated) = clamp(stripANSI(raw), to: resultLimit)
        return ToolResult(text: text, truncated: truncated, isError: isError)
    }

    static func stripANSI(_ text: String) -> String {
        guard text.contains("\u{1B}") else { return text }
        return text.replacing(/\x1B\[[0-9;?]*[ -\/]*[@-~]|\x1B[@-Z\\\-_]/, with: "")
    }

    /// Cuts `text` to `limit` UTF-16 code units, as Collie measures, and says whether it cut.
    static func clamp(_ text: String, to limit: Int) -> (text: String, truncated: Bool) {
        guard text.utf16.count > limit else { return (text, false) }
        return (String(decoding: Array(text.utf16.prefix(limit)), as: UTF16.self), true)
    }

    /// Collapses whitespace to single spaces and caps the result at 200 characters with an ellipsis.
    static func oneLine(_ text: String) -> String {
        let collapsed = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return collapsed.count > summaryLimit ? String(collapsed.prefix(summaryLimit - 1)) + "…" : collapsed
    }

    /// The first non-empty string among `summaryKeys`, else the first non-empty string value by key order.
    static func summarizeToolInput(_ input: Any?) -> String {
        guard let input = input as? [String: Any] else {
            return (input as? String).map(oneLine) ?? ""
        }
        let keys = summaryKeys + input.keys.sorted()
        for key in keys {
            if let value = input[key] as? String, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return oneLine(value)
            }
            if let values = input[key] as? [String], !values.isEmpty {
                return oneLine(values.joined(separator: " "))
            }
        }
        return ""
    }
}
