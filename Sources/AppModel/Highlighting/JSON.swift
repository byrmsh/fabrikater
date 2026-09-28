extension LexRules {
    /// JSON, with the comments JSONC allows. Object keys read apart from string values.
    static let json = LexRules(
        keywords: ["true", "false", "null"],
        lineComments: ["//"],
        blockComment: ("/*", "*/"),
        quotes: [LexRules.Quote(delimiter: "\"")],
        keysBeforeColon: true
    )
}
