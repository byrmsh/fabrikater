/// What sets one C-like language's tokens apart. Each language file defines one of these.
struct LexRules: Sendable {
    struct Quote: Sendable {
        var delimiter: String
        var multiline = false
        var escapes = true
    }

    var keywords: Set<String> = []
    /// Names coloured as types though they start lowercase (`int`, `str`), or, with `capitalizedTypes`, besides them.
    var types: Set<String> = []
    /// Treats every identifier that starts uppercase as a type, as Swift, Python and JavaScript code reads.
    var capitalizedTypes = false
    var lineComments: [String] = []
    var blockComment: (open: String, close: String)?
    /// Checked in order, so a triple quote comes before its single one.
    var quotes: [Quote] = []
    /// Identifiers that fold into a string they touch, as Python's `f"…"`.
    var stringPrefixes: Set<String> = []
    /// Characters that start an attribute or decorator with the identifier after them (`@MainActor`, `#if`).
    var attributeMarks: Set<Unicode.Scalar> = []
    /// Starts a variable with the name after it (shell `$HOME`, `${name}`).
    var variableMark: Unicode.Scalar?
    /// Extra scalars an identifier may hold, beyond letters, digits and `_` (`$` in JavaScript, `-` in shell words).
    var identifierExtras: Set<Unicode.Scalar> = []
    /// A line comment starts only at a line's start or after a space, as shell's `#` does.
    var commentsNeedSpaceBefore = false
    /// A string followed by `:` is an object key, as in JSON.
    var keysBeforeColon = false
}

/// One pass over the scalars of the code, emitting tokens as the rules say. Anything unrecognised is plain.
struct Lexer {
    let rules: LexRules

    func tokens(_ code: String) -> [CodeToken] {
        var scan = Scan(Array(code.unicodeScalars))
        while !scan.isAtEnd {
            step(&scan)
        }
        return scan.output
    }

    private func step(_ scan: inout Scan) {
        let scalar = scan.current
        if let comment = rules.blockComment, scan.starts(with: comment.open) {
            scan.take(.comment, count: scan.length(through: comment.close, from: comment.open.unicodeScalars.count))
        } else if rules.lineComments.contains(where: { scan.starts(with: $0) }),
            !rules.commentsNeedSpaceBefore || scan.previous.map(Self.isSpace) ?? true
        {
            scan.take(.comment, count: scan.distanceToLineEnd())
        } else if let quote = rules.quotes.first(where: { scan.starts(with: $0.delimiter) }) {
            let kind: CodeToken.Kind = rules.keysBeforeColon && isKey(scan, quote) ? .key : .string
            scan.take(kind, count: stringLength(scan, quote))
        } else if rules.variableMark == scalar, scan.offset(1).map(Self.startsVariable) ?? false {
            scan.take(.variable, count: variableLength(scan))
        } else if rules.attributeMarks.contains(scalar), scan.offset(1).map(Self.startsIdentifier) ?? false {
            scan.take(.attribute, count: 1 + identifierLength(scan, from: 1))
        } else if Self.isDigit(scalar), !(scan.previous.map(isIdentifierScalar) ?? false) {
            scan.take(.number, count: numberLength(scan))
        } else if Self.startsIdentifier(scalar) {
            let length = identifierLength(scan, from: 0)
            let word = scan.text(count: length)
            if rules.stringPrefixes.contains(word),
                let quote = rules.quotes.first(where: { scan.starts(with: $0.delimiter, at: length) })
            {
                scan.take(.string, count: length + stringLength(scan, quote, at: length))
            } else {
                scan.take(kind(of: word), count: length)
            }
        } else {
            scan.take(.plain, count: 1)
        }
    }

    private func kind(of word: String) -> CodeToken.Kind {
        if rules.keywords.contains(word) { return .keyword }
        if rules.types.contains(word) { return .type }
        if rules.capitalizedTypes, let first = word.unicodeScalars.first, first.properties.isUppercase { return .type }
        return .plain
    }

    /// The string's length from `at`, through its closing quote, or to the line's end (the code's end when it is
    /// multiline) when it is not closed.
    private func stringLength(_ scan: Scan, _ quote: LexRules.Quote, at start: Int = 0) -> Int {
        let open = quote.delimiter.unicodeScalars.count
        var length = open
        while let scalar = scan.offset(start + length) {
            if scan.starts(with: quote.delimiter, at: start + length) { return length + open }
            if scalar == "\n", !quote.multiline { return length }
            length += quote.escapes && scalar == "\\" && scan.offset(start + length + 1) != nil ? 2 : 1
        }
        return length
    }

    private func isKey(_ scan: Scan, _ quote: LexRules.Quote) -> Bool {
        var after = stringLength(scan, quote)
        while let scalar = scan.offset(after), scalar == " " || scalar == "\t" { after += 1 }
        return scan.offset(after) == ":"
    }

    private func variableLength(_ scan: Scan) -> Int {
        if scan.offset(1) == "{" {
            var length = 2
            while let scalar = scan.offset(length), scalar != "}", scalar != "\n" { length += 1 }
            return scan.offset(length) == "}" ? length + 1 : length
        }
        if let next = scan.offset(1), !Self.startsIdentifier(next) { return 2 }
        var length = 1
        while let scalar = scan.offset(length), Self.startsIdentifier(scalar) || Self.isDigit(scalar) { length += 1 }
        return length
    }

    private func identifierLength(_ scan: Scan, from start: Int) -> Int {
        var length = 0
        while let scalar = scan.offset(start + length), isIdentifierScalar(scalar) { length += 1 }
        return length
    }

    /// Digits, a hex or binary prefix, `_` separators, a fraction and an exponent, but not a range's `..`.
    private func numberLength(_ scan: Scan) -> Int {
        var length = 1
        while let scalar = scan.offset(length) {
            if scalar == "." {
                guard scan.offset(length + 1).map(Self.isDigit) ?? false else { break }
            } else if !(Self.isDigit(scalar) || Self.isLetter(scalar) || scalar == "_") {
                break
            }
            length += 1
        }
        return length
    }

    private func isIdentifierScalar(_ scalar: Unicode.Scalar) -> Bool {
        Self.startsIdentifier(scalar) || Self.isDigit(scalar) || rules.identifierExtras.contains(scalar)
    }

    private static func startsIdentifier(_ scalar: Unicode.Scalar) -> Bool {
        isLetter(scalar) || scalar == "_"
    }

    private static func startsVariable(_ scalar: Unicode.Scalar) -> Bool {
        startsIdentifier(scalar) || isDigit(scalar) || "{?#@*!$".unicodeScalars.contains(scalar)
    }

    private static func isLetter(_ scalar: Unicode.Scalar) -> Bool {
        scalar.properties.isAlphabetic
    }

    private static func isDigit(_ scalar: Unicode.Scalar) -> Bool {
        ("0"..."9").contains(scalar)
    }

    private static func isSpace(_ scalar: Unicode.Scalar) -> Bool {
        scalar == " " || scalar == "\t" || scalar == "\n"
    }
}

/// A cursor over the code's scalars that collects tokens, merging neighbours of the same kind.
struct Scan {
    private let scalars: [Unicode.Scalar]
    private var index = 0
    private(set) var output: [CodeToken] = []

    init(_ scalars: [Unicode.Scalar]) {
        self.scalars = scalars
    }

    var isAtEnd: Bool { index >= scalars.count }
    var current: Unicode.Scalar { scalars[index] }
    var previous: Unicode.Scalar? { index > 0 ? scalars[index - 1] : nil }

    func offset(_ distance: Int) -> Unicode.Scalar? {
        index + distance < scalars.count ? scalars[index + distance] : nil
    }

    func starts(with prefix: String, at distance: Int = 0) -> Bool {
        var position = index + distance
        for scalar in prefix.unicodeScalars {
            guard position < scalars.count, scalars[position] == scalar else { return false }
            position += 1
        }
        return true
    }

    func text(count: Int) -> String {
        var view = String.UnicodeScalarView()
        view.append(contentsOf: scalars[index..<min(index + count, scalars.count)])
        return String(view)
    }

    /// The length up to and including the first `marker` at or past `start`, or the rest of the code without one.
    func length(through marker: String, from start: Int) -> Int {
        var distance = start
        while index + distance < scalars.count {
            if starts(with: marker, at: distance) { return distance + marker.unicodeScalars.count }
            distance += 1
        }
        return distance
    }

    func distanceToLineEnd() -> Int {
        var distance = 0
        while let scalar = offset(distance), scalar != "\n" { distance += 1 }
        return distance
    }

    mutating func take(_ kind: CodeToken.Kind, count: Int) {
        let text = text(count: max(count, 1))
        index = min(index + max(count, 1), scalars.count)
        if let last = output.last, last.kind == kind {
            output[output.count - 1].text += text
        } else {
            output.append(CodeToken(kind, text))
        }
    }
}
