/// A unified diff, line by line: added and removed lines, and hunk and file headers.
enum DiffTokenizer {
    static func tokens(_ code: String) -> [CodeToken] {
        var tokens: [CodeToken] = []
        let lines = code.split(separator: "\n", omittingEmptySubsequences: false)
        for (number, line) in lines.enumerated() {
            let text = number == lines.count - 1 ? String(line) : line + "\n"
            let kind = kind(of: line)
            if let last = tokens.last, last.kind == kind {
                tokens[tokens.count - 1].text += text
            } else {
                tokens.append(CodeToken(kind, text))
            }
        }
        return tokens
    }

    private static func kind(of line: Substring) -> CodeToken.Kind {
        let headers = [
            "+++ ", "--- ", "diff ", "index ", "@@", "new file mode", "deleted file mode", "similarity index",
        ]
        if headers.contains(where: { line.hasPrefix($0) }) { return .meta }
        if line.hasPrefix("+") { return .added }
        if line.hasPrefix("-") { return .removed }
        return .plain
    }
}
