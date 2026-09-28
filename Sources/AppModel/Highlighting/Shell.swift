extension LexRules {
    static let shell = LexRules(
        keywords: [
            "if", "then", "else", "elif", "fi", "for", "while", "until", "do", "done", "case", "esac", "in",
            "function", "return", "select", "time", "export", "local", "readonly", "declare", "unset", "set",
            "source", "exec", "eval", "exit", "shift", "trap", "break", "continue", "sudo",
        ],
        lineComments: ["#"],
        quotes: [
            LexRules.Quote(delimiter: "\"", multiline: true),
            LexRules.Quote(delimiter: "'", multiline: true, escapes: false),
        ],
        variableMark: "$",
        identifierExtras: ["-", "."],
        commentsNeedSpaceBefore: true
    )
}
