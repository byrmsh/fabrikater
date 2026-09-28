import Foundation

/// A pane's screen as `herdr pane read … --format ansi` prints it, reduced to plain text lines.
public struct Screen: Equatable, Sendable {
    /// Top to bottom, with styling and trailing spaces removed.
    public let lines: [String]
    /// The same lines without the text drawn faint (SGR 2), which is how Claude Code paints a suggested prompt.
    let unfaint: [String]

    public init(ansi: String) {
        var plain = ""
        var unfaint = ""
        var faint = false
        var rest = ansi[...]
        while let escape = rest.firstMatch(of: /\x1B\[([0-9;?]*)[ -\/]*([@-~])|\x1B[@-Z\\\-_]/) {
            let text = rest[..<escape.range.lowerBound]
            plain += text
            unfaint += faint ? String(text.filter(\.isNewline)) : String(text)
            if escape.output.2 == "m", let parameters = escape.output.1 {
                faint = Self.faint(after: parameters, was: faint)
            }
            rest = rest[escape.range.upperBound...]
        }
        plain += rest
        unfaint += faint ? String(rest.filter(\.isNewline)) : String(rest)
        lines = Self.lines(plain)
        self.unfaint = Self.lines(unfaint)
    }

    /// `\r\n` is one Character in Swift, so this splits on any newline rather than on `\n`.
    private static func lines(_ text: String) -> [String] {
        text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map { line in
            var line = line
            while line.last?.isWhitespace == true { line.removeLast() }
            return String(line)
        }
    }

    /// SGR 2 turns faint on; 0 (or no parameter) and 22 turn it off. The numbers of an extended colour
    /// (`38;2;r;g;b`, `48;5;n`) are skipped, so a `2` among them is not read as faint.
    private static func faint(after parameters: Substring, was faint: Bool) -> Bool {
        var faint = faint
        let codes = parameters.split(separator: ";", omittingEmptySubsequences: false).map { Int($0) ?? 0 }
        var index = 0
        while index < codes.count {
            switch codes[index] {
            case 0, 22: faint = false
            case 2: faint = true
            case 38, 48, 58:
                let mode = index + 1 < codes.count ? codes[index + 1] : 0
                index += mode == 2 ? 4 : mode == 5 ? 2 : 0
            default: break
            }
            index += 1
        }
        return faint
    }

    /// The last `count` lines that are not blank, top to bottom.
    func lastNonBlank(_ count: Int) -> ArraySlice<String> {
        let nonBlank = lines.filter { !$0.allSatisfy(\.isWhitespace) }
        return nonBlank.suffix(count)
    }
}
