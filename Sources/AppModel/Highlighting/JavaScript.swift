/// JavaScript and TypeScript, whose keywords are a superset of JavaScript's.
extension LexRules {
    static let javascript = LexRules(
        keywords: [
            "abstract", "as", "async", "await", "break", "case", "catch", "class", "const", "constructor", "continue",
            "debugger", "declare", "default", "delete", "do", "else", "enum", "export", "extends", "false", "finally",
            "for", "from", "function", "get", "if", "implements", "import", "in", "instanceof", "interface", "keyof",
            "let", "namespace", "new", "null", "of", "private", "protected", "public", "readonly", "return",
            "satisfies",
            "set", "static", "super", "switch", "this", "throw", "true", "try", "type", "typeof", "undefined", "var",
            "void", "while", "with", "yield",
        ],
        types: ["string", "number", "boolean", "any", "unknown", "never", "object", "bigint", "symbol"],
        capitalizedTypes: true,
        lineComments: ["//"],
        blockComment: ("/*", "*/"),
        quotes: [
            LexRules.Quote(delimiter: "`", multiline: true), LexRules.Quote(delimiter: "\""),
            LexRules.Quote(delimiter: "'"),
        ],
        attributeMarks: ["@"],
        identifierExtras: ["$"]
    )
}
