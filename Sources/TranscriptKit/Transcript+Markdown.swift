/// Markdown for copying a conversation or one of its messages out of the app.
extension Transcript {
    /// The entries as one document: each under a heading naming its role, separated by blank lines.
    public static func markdown(of entries: some Sequence<TranscriptEntry>) -> String {
        let blocks = entries.map { "### \(heading(of: $0.role))\n\n\(markdownBody(of: $0))" }
        return blocks.isEmpty ? "" : blocks.joined(separator: "\n\n") + "\n"
    }

    /// One entry without a heading: its text as written, tool calls as a name and fenced input, and summaries and
    /// notes as block quotes.
    public static func markdownBody(of entry: TranscriptEntry) -> String {
        let body = entry.parts.map(markdown(of:)).joined(separator: "\n\n")
        switch entry.role {
        case .user, .assistant: return body
        case .summary, .note: return quoted(body)
        }
    }

    private static func heading(of role: TranscriptEntry.Role) -> String {
        switch role {
        case .user: "User"
        case .assistant: "Assistant"
        case .summary: "Summary"
        case .note: "Note"
        }
    }

    private static func markdown(of part: TranscriptPart) -> String {
        switch part {
        case .text(let text, let truncated):
            return truncated ? text + "…" : text
        case .tool(let call):
            let title = "**\(call.name)**" + (call.result?.isError == true ? " (failed)" : "")
            // A result whose call fell outside the window read has no input to show, only its output.
            let body = call.summary.isEmpty ? call.result?.text ?? "" : call.summary
            return body.isEmpty ? title : title + "\n\n" + fenced(body)
        }
    }

    /// A code block whose fence is longer than any backtick run inside it, so the content cannot close it.
    private static func fenced(_ text: String) -> String {
        let fence = String(repeating: "`", count: max(3, longestBacktickRun(in: text) + 1))
        return "\(fence)\n\(text)\n\(fence)"
    }

    private static func longestBacktickRun(in text: String) -> Int {
        var longest = 0
        var run = 0
        for character in text {
            run = character == "`" ? run + 1 : 0
            longest = max(longest, run)
        }
        return longest
    }

    private static func quoted(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.isEmpty ? ">" : "> \($0)" }
            .joined(separator: "\n")
    }
}
