// Agent replies as blocks the conversation lays out one by one: headings, paragraphs, lists, code, quotes and tables.
// Inline styling (emphasis, inline code, links) stays in each block's text for the view's inline markdown parser.

import Foundation

/// One block of a markdown message.
public enum MarkdownBlock: Equatable, Sendable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case list([ListItem])
    /// A fenced code block. `language` is the fence's info word, empty when it has none.
    case code(language: String, text: String)
    case quote([MarkdownBlock])
    case table(MarkdownTable)
    case rule

    /// Parses `text` line by line. An unclosed fence runs to the end, as in a reply still being written.
    public static func parse(_ text: String) -> [MarkdownBlock] {
        var parser = Parser(lines: text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init))
        return parser.blocks()
    }
}

/// One list item, already numbered or bulleted, at its nesting depth.
public struct ListItem: Equatable, Sendable {
    /// 0 for a top-level item, 1 for an item nested under it, and so on.
    public var level: Int
    /// What the view draws before the text: "•", "3.", or a checkbox for a task item.
    public var marker: String
    public var text: String

    public init(level: Int, marker: String, text: String) {
        self.level = level
        self.marker = marker
        self.text = text
    }
}

public struct MarkdownTable: Equatable, Sendable {
    public enum Alignment: Equatable, Sendable { case leading, center, trailing }

    public var header: [String]
    public var alignments: [Alignment]
    /// Each row has exactly as many cells as the header.
    public var rows: [[String]]

    public init(header: [String], alignments: [Alignment], rows: [[String]]) {
        self.header = header
        self.alignments = alignments
        self.rows = rows
    }
}

private struct Parser {
    let lines: [String]
    var index = 0

    init(lines: [String]) {
        self.lines = lines
    }

    mutating func blocks() -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        while index < lines.count {
            let line = lines[index]
            if line.isBlank {
                index += 1
            } else if let fence = Fence(line) {
                blocks.append(code(fence))
            } else if let heading = Self.heading(line) {
                blocks.append(heading)
                index += 1
            } else if Self.isRule(line) {
                blocks.append(.rule)
                index += 1
            } else if Self.quoted(line) != nil {
                blocks.append(quote())
            } else if ListLine(line) != nil {
                blocks.append(list())
            } else if let table = table() {
                blocks.append(.table(table))
            } else {
                blocks.append(paragraph())
            }
        }
        return blocks
    }

    private mutating func code(_ fence: Fence) -> MarkdownBlock {
        index += 1
        var body: [String] = []
        while index < lines.count, !fence.isClosed(by: lines[index]) {
            body.append(fence.unindented(lines[index]))
            index += 1
        }
        index += 1
        return .code(language: fence.language, text: body.joined(separator: "\n"))
    }

    private mutating func quote() -> MarkdownBlock {
        var inner: [String] = []
        while index < lines.count, let text = Self.quoted(lines[index]) {
            inner.append(text)
            index += 1
        }
        var nested = Parser(lines: inner)
        return .quote(nested.blocks())
    }

    private mutating func list() -> MarkdownBlock {
        var items: [ListItem] = []
        var indents: [Int] = []
        var numbers: [Int] = []
        var afterBlank = false
        while index < lines.count {
            let line = lines[index]
            if Fence(line) != nil {
                // A code block inside an item is laid out as its own block, and the list resumes after it.
                break
            } else if let item = ListLine(line) {
                while let last = indents.last, item.indent < last {
                    indents.removeLast()
                    numbers.removeLast()
                }
                if indents.last.map({ item.indent > $0 }) ?? true {
                    indents.append(item.indent)
                    numbers.append(item.number ?? 1)
                } else if let number = numbers.last {
                    numbers[numbers.count - 1] = number + 1
                }
                let marker = item.task ?? (item.number == nil ? "•" : "\(numbers[numbers.count - 1]).")
                items.append(ListItem(level: indents.count - 1, marker: marker, text: item.text))
                afterBlank = false
                index += 1
            } else if line.isBlank {
                // A blank line ends the list unless an item or an indented continuation follows it.
                let next = lines[(index + 1)...].first { !$0.isBlank }
                guard let next, ListLine(next) != nil || next.leadingSpaces >= 2 else { break }
                afterBlank = true
                index += 1
            } else if !items.isEmpty, line.leadingSpaces >= 2 || !startsBlock(line) {
                items[items.count - 1].text += (afterBlank ? "\n\n" : "\n") + line.trimmingLeadingSpaces
                afterBlank = false
                index += 1
            } else {
                break
            }
        }
        return .list(items)
    }

    private mutating func table() -> MarkdownTable? {
        guard index + 1 < lines.count, lines[index].contains("|"),
            let alignments = Self.delimiter(lines[index + 1])
        else { return nil }
        let header = Self.cells(lines[index])
        guard header.count == alignments.count else { return nil }
        index += 2
        var rows: [[String]] = []
        while index < lines.count, lines[index].contains("|"), !lines[index].isBlank {
            let cells = Self.cells(lines[index])
            rows.append((0..<header.count).map { $0 < cells.count ? cells[$0] : "" })
            index += 1
        }
        return MarkdownTable(header: header, alignments: alignments, rows: rows)
    }

    private mutating func paragraph() -> MarkdownBlock {
        var body = [lines[index].trimmingLeadingSpaces]
        index += 1
        while index < lines.count, !lines[index].isBlank, !startsBlock(lines[index]) {
            body.append(lines[index].trimmingLeadingSpaces)
            index += 1
        }
        return .paragraph(body.joined(separator: "\n"))
    }

    /// True when `line` would open a block other than a paragraph, which ends the paragraph or list item before it.
    private func startsBlock(_ line: String) -> Bool {
        Fence(line) != nil || Self.heading(line) != nil || Self.isRule(line) || Self.quoted(line) != nil
            || ListLine(line) != nil
            || (index + 1 < lines.count && line.contains("|") && Self.delimiter(lines[index + 1]) != nil)
    }

    private static func heading(_ line: String) -> MarkdownBlock? {
        guard line.leadingSpaces < 4 else { return nil }
        let trimmed = line.trimmingLeadingSpaces
        let level = trimmed.prefix { $0 == "#" }.count
        guard (1...6).contains(level) else { return nil }
        let rest = trimmed.dropFirst(level)
        guard rest.isEmpty || rest.first == " " || rest.first == "\t" else { return nil }
        var text = rest.trimmingCharacters(in: .whitespaces)
        if text.hasSuffix("#") {
            let stripped = String(text.reversed().drop { $0 == "#" }.reversed())
            if stripped.isEmpty || stripped.hasSuffix(" ") { text = stripped.trimmingCharacters(in: .whitespaces) }
        }
        return .heading(level: level, text: text)
    }

    private static func isRule(_ line: String) -> Bool {
        guard line.leadingSpaces < 4 else { return false }
        let marks = line.filter { $0 != " " && $0 != "\t" }
        guard let first = marks.first, "-*_".contains(first), marks.count >= 3 else { return false }
        return marks.allSatisfy { $0 == first }
    }

    /// The line's text without its `>` marker, or nil when it is not a quote line.
    private static func quoted(_ line: String) -> String? {
        guard line.leadingSpaces < 4 else { return nil }
        let trimmed = line.trimmingLeadingSpaces
        guard trimmed.hasPrefix(">") else { return nil }
        let rest = trimmed.dropFirst()
        return String(rest.first == " " ? rest.dropFirst() : rest)
    }

    /// The column alignments of a table's delimiter row (`| --- | :-: |`), or nil when `line` is not one.
    private static func delimiter(_ line: String) -> [MarkdownTable.Alignment]? {
        guard line.contains("-") else { return nil }
        let cells = cells(line)
        guard !cells.isEmpty else { return nil }
        var alignments: [MarkdownTable.Alignment] = []
        for cell in cells {
            let dashes = cell.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
            guard !dashes.isEmpty, dashes.allSatisfy({ $0 == "-" }) else { return nil }
            switch (cell.hasPrefix(":"), cell.hasSuffix(":")) {
            case (true, true): alignments.append(.center)
            case (false, true): alignments.append(.trailing)
            default: alignments.append(.leading)
            }
        }
        return alignments
    }

    /// A table row's cells, trimmed, without the outer pipes. `\|` stays a literal pipe inside a cell.
    private static func cells(_ line: String) -> [String] {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("|") { trimmed.removeFirst() }
        if trimmed.hasSuffix("|"), !trimmed.hasSuffix("\\|") { trimmed.removeLast() }
        var cells: [String] = []
        var cell = ""
        var escaped = false
        for character in trimmed {
            if escaped {
                cell.append(character == "|" ? "|" : "\\\(character)")
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else if character == "|" {
                cells.append(cell)
                cell = ""
            } else {
                cell.append(character)
            }
        }
        if escaped { cell.append("\\") }
        cells.append(cell)
        return cells.map { $0.trimmingCharacters(in: .whitespaces) }
    }
}

/// An opening code fence: three or more backticks or tildes, and the info word after them.
private struct Fence {
    let character: Character
    let length: Int
    let indent: Int
    let language: String

    init?(_ line: String) {
        indent = line.leadingSpaces
        let trimmed = line.trimmingLeadingSpaces
        guard let first = trimmed.first, first == "`" || first == "~" else { return nil }
        length = trimmed.prefix { $0 == first }.count
        guard length >= 3 else { return nil }
        let info = trimmed.dropFirst(length).trimmingCharacters(in: .whitespaces)
        guard first == "~" || !info.contains("`") else { return nil }
        character = first
        language = info.split(separator: " ").first.map(String.init) ?? ""
    }

    /// Fences may sit at any indent, since agents indent code under list items.
    func isClosed(by line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.count >= length && trimmed.allSatisfy { $0 == character }
    }

    /// Removes up to the fence's own indent from a code line, as CommonMark does.
    func unindented(_ line: String) -> String {
        String(line.dropFirst(min(indent, line.leadingSpaces)))
    }
}

/// A list item line: `- text`, `* text`, `+ text`, `1. text` or `1) text`, with an optional task box.
private struct ListLine {
    let indent: Int
    /// The item's number, or nil for a bullet.
    let number: Int?
    /// "☐" or "☑" for a task item (`- [ ] text`), else nil.
    let task: String?
    let text: String

    init?(_ line: String) {
        indent = line.leadingSpaces
        let trimmed = line.trimmingLeadingSpaces
        var rest: Substring
        if let first = trimmed.first, "-*+".contains(first) {
            number = nil
            rest = trimmed.dropFirst()
        } else {
            let digits = trimmed.prefix { $0.isASCII && $0.isNumber }
            let after = trimmed.dropFirst(digits.count)
            guard (1...9).contains(digits.count), let delimiter = after.first, delimiter == "." || delimiter == ")"
            else { return nil }
            number = Int(digits)
            rest = after.dropFirst()
        }
        guard rest.first == " " || rest.first == "\t" else { return nil }
        rest = rest.drop { $0 == " " || $0 == "\t" }
        guard !rest.isEmpty else { return nil }
        if rest.hasPrefix("[ ] ") || rest.hasPrefix("[x] ") || rest.hasPrefix("[X] ") {
            task = rest.hasPrefix("[ ]") ? "☐" : "☑"
            rest = rest.dropFirst(4)
        } else {
            task = nil
        }
        text = String(rest)
    }
}

extension String {
    fileprivate var isBlank: Bool {
        allSatisfy { $0 == " " || $0 == "\t" }
    }

    /// Leading spaces, with a tab counting as four.
    fileprivate var leadingSpaces: Int {
        prefix { $0 == " " || $0 == "\t" }.reduce(0) { $0 + ($1 == "\t" ? 4 : 1) }
    }

    fileprivate var trimmingLeadingSpaces: String {
        String(drop { $0 == " " || $0 == "\t" })
    }
}
