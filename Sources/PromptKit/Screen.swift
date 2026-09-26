import Foundation

/// A pane's screen as `herdr pane read … --format ansi` prints it, reduced to plain text lines.
public struct Screen: Equatable, Sendable {
    /// Top to bottom, with styling and trailing spaces removed.
    public let lines: [String]

    public init(ansi: String) {
        var plain = ansi
        if plain.contains("\u{1B}") {
            plain.replace(/\x1B\[[0-9;?]*[ -\/]*[@-~]|\x1B[@-Z\\\-_]/, with: "")
        }
        // `\r\n` is one Character in Swift, so split on any newline rather than on `\n`.
        lines = plain.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map { line in
            var line = line
            while line.last?.isWhitespace == true { line.removeLast() }
            return String(line)
        }
    }

    /// The last `count` lines that are not blank, top to bottom.
    func lastNonBlank(_ count: Int) -> ArraySlice<String> {
        let nonBlank = lines.filter { !$0.allSatisfy(\.isWhitespace) }
        return nonBlank.suffix(count)
    }
}
