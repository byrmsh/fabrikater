// Syntax highlighting for code blocks and diffs: each language is a pure tokenizer in its own file, and the view
// colours the tokens with `CodePalette`.

/// A run of code text and what it is. A tokenizer's tokens, joined, give back its input exactly.
public struct CodeToken: Equatable, Sendable {
    public enum Kind: Equatable, Sendable, CaseIterable {
        case plain, keyword, type, string, number, comment, attribute, variable, key
        /// Diff lines: added, removed, and the hunk and file headers.
        case added, removed, meta
    }

    public var kind: Kind
    public var text: String

    public init(_ kind: Kind, _ text: String) {
        self.kind = kind
        self.text = text
    }
}

/// The languages agents' code blocks most often use. TypeScript shares JavaScript's tokenizer.
public enum CodeLanguage: Equatable, Sendable, CaseIterable {
    case swift, shell, python, javascript, json, diff

    /// Longer code is shown plain, so a huge block or file costs nothing to render.
    public static let highlightLimit = 60_000

    /// The language a code fence's info word names (```` ```ts ````), case-insensitively, or nil when unknown.
    public init?(fence: String) {
        let names: [String: CodeLanguage] = [
            "swift": .swift,
            "sh": .shell, "bash": .shell, "zsh": .shell, "shell": .shell, "console": .shell, "shellsession": .shell,
            "py": .python, "python": .python, "python3": .python,
            "js": .javascript, "javascript": .javascript, "jsx": .javascript, "mjs": .javascript,
            "ts": .javascript, "typescript": .javascript, "tsx": .javascript,
            "json": .json, "jsonc": .json, "json5": .json, "jsonl": .json,
            "diff": .diff, "patch": .diff, "udiff": .diff,
        ]
        guard let language = names[fence.lowercased()] else { return nil }
        self = language
    }

    /// The language of a file by its extension (`Uploader.swift`), or nil when unknown.
    public init?(path: String) {
        let name = path.split(separator: "/").last.map(String.init) ?? path
        guard let dot = name.lastIndex(of: "."), dot != name.startIndex else { return nil }
        let ext = String(name[name.index(after: dot)...])
        guard ext.lowercased() != "console", let language = CodeLanguage(fence: ext) else { return nil }
        self = language
    }

    public func tokens(_ code: String) -> [CodeToken] {
        guard code.utf8.count <= Self.highlightLimit else { return [CodeToken(.plain, code)] }
        switch self {
        case .swift: return Lexer(rules: .swift).tokens(code)
        case .shell: return Lexer(rules: .shell).tokens(code)
        case .python: return Lexer(rules: .python).tokens(code)
        case .javascript: return Lexer(rules: .javascript).tokens(code)
        case .json: return Lexer(rules: .json).tokens(code)
        case .diff: return DiffTokenizer.tokens(code)
        }
    }

    /// `code` highlighted as the fence's language says, or as one plain token when it names none we know.
    public static func tokens(_ code: String, fence: String) -> [CodeToken] {
        CodeLanguage(fence: fence)?.tokens(code) ?? [CodeToken(.plain, code)]
    }
}
