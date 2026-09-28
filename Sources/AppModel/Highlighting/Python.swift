extension LexRules {
    static let python = LexRules(
        keywords: [
            "False", "None", "True", "and", "as", "assert", "async", "await", "break", "class", "continue", "def",
            "del", "elif", "else", "except", "finally", "for", "from", "global", "if", "import", "in", "is", "lambda",
            "match", "case", "nonlocal", "not", "or", "pass", "raise", "return", "try", "while", "with", "yield",
            "self", "cls",
        ],
        types: ["int", "float", "str", "bool", "bytes", "list", "dict", "set", "tuple", "object", "type"],
        capitalizedTypes: true,
        lineComments: ["#"],
        quotes: [
            LexRules.Quote(delimiter: "\"\"\"", multiline: true), LexRules.Quote(delimiter: "'''", multiline: true),
            LexRules.Quote(delimiter: "\""), LexRules.Quote(delimiter: "'"),
        ],
        stringPrefixes: ["f", "r", "b", "u", "rb", "br", "fr", "rf", "F", "R", "B", "U"],
        attributeMarks: ["@"]
    )
}
