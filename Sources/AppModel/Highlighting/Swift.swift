extension LexRules {
    static let swift = LexRules(
        keywords: [
            "actor", "any", "as", "associatedtype", "async", "await", "break", "case", "catch", "class", "continue",
            "convenience", "default", "defer", "deinit", "do", "else", "enum", "extension", "fallthrough", "false",
            "fileprivate", "final", "for", "func", "guard", "if", "import", "in", "indirect", "init", "inout",
            "internal", "is", "isolated", "lazy", "let", "mutating", "nil", "nonisolated", "nonmutating", "open",
            "operator", "override", "package", "private", "protocol", "public", "repeat", "required", "rethrows",
            "return", "self", "Self", "sending", "some", "static", "struct", "subscript", "super", "switch", "throw",
            "throws", "true", "try", "typealias", "var", "weak", "unowned", "where", "while", "consuming", "borrowing",
        ],
        capitalizedTypes: true,
        lineComments: ["//"],
        blockComment: ("/*", "*/"),
        quotes: [LexRules.Quote(delimiter: "\"\"\"", multiline: true), LexRules.Quote(delimiter: "\"")],
        attributeMarks: ["@", "#"]
    )
}
