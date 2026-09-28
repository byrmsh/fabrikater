// Ported from AltanS/collie@b7ddc17 (MIT): web/src/lib/harness/claude/prompt-select.ts (`detectPromptSelectRegion`)
// and web/src/lib/harness/claude/markers.ts (`classifyFooter`, `isHorizontalRule`, `isMultiStepHeader`), simplified
// as docs/parsing.md 4.3 describes.
import Foundation

/// A Claude Code dialog with numbered options at the bottom of the screen: a permission prompt, a single
/// `AskUserQuestion`, a plan approval or the folder-trust prompt. Answering it is pressing an option's digit, plus
/// Enter for a question.
public struct Prompt: Equatable, Sendable {
    public enum Family: String, Equatable, Sendable {
        /// `AskUserQuestion`: the digit moves the pointer, Enter confirms.
        case select
        /// A tool's permission prompt: the digit alone answers.
        case permission
        /// Plan approval: the digit alone answers.
        case plan
        /// The folder-trust prompt: the digit alone answers.
        case trust
    }

    public struct Option: Equatable, Sendable, Identifiable {
        /// What the user presses.
        public let number: Int
        public let label: String
        public let description: String?

        public var id: Int { number }
    }

    public let family: Family
    public let question: String
    /// What the dialog is about, above its question: a command, a file, an `AskUserQuestion` header.
    public let subject: [String]
    /// The options to show. Rows answered by typing (`Type something.`, `Tell Claude what to change`) are left out.
    public let options: [Option]
    /// The rows from the question through the footer, which must still show when the answer is sent.
    public let region: [String]
    /// The rows from well above the options through the footer. A fresh read must match them before an answer goes,
    /// which tells two prompts of the same shape apart by what they ask about.
    let signature: [String]

    /// True when the digit only moves the pointer and Enter must follow it.
    public var confirmsWithEnter: Bool { family == .select }

    /// The prompt at the bottom of `screen`, or nil when the screen shows none this grammar knows, so a guess is
    /// never offered as an answer.
    public init?(on screen: Screen) {
        let lines = screen.lines
        guard let footer = lines.lastIndex(where: { !Self.isBlank($0) }),
            let family = Family(footer: lines[footer], screen: lines)
        else { return nil }

        let rows = (max(0, footer - Self.optionScan)..<footer).compactMap { index in
            Self.optionRow(lines[index]).map { Row(index: index, number: $0.number, label: $0.label) }
        }
        let menu = Self.trailingMenu(rows)
        // More than nine would need two digits.
        guard menu.count >= 2, menu.count <= 9, let first = menu.first?.index, let last = menu.last?.index else {
            return nil
        }
        let hinted = lines[(last + 1)..<footer].contains { Self.isFeedbackHint($0) }
        guard footer - last <= Self.footerGap + (hinted ? Self.feedbackWrap : 0) else { return nil }
        // A multi-question `AskUserQuestion` shows a stepper; one digit and Enter would answer only its first step.
        if family == .select, lines[max(0, first - Self.questionScan)..<footer].contains(where: Self.isStepper) {
            return nil
        }
        guard let questionAt = Self.question(in: lines, above: first) else { return nil }

        var options: [Option] = []
        for (offset, row) in menu.enumerated() {
            let next = offset + 1 < menu.count ? menu[offset + 1].index : footer
            let description = lines[(row.index + 1)..<next]
                .filter { !Self.isBlank($0) && !Self.isRule($0) && Self.optionRow($0) == nil }
                .map { $0.trimmingCharacters(in: .whitespaces) }
            if Self.isFreeText(row.label) || description.contains(where: Self.isFeedbackHint) {
                // With the pointer on a text row, a digit is typed into it instead of choosing.
                if Self.isPointed(lines[row.index]) { return nil }
                continue
            }
            options.append(
                Option(
                    number: row.number, label: row.label,
                    description: description.isEmpty ? nil : description.joined(separator: " ")))
        }
        guard !options.isEmpty else { return nil }

        self.family = family
        self.options = options
        question = lines[questionAt].trimmingCharacters(in: .whitespaces)
        subject = Self.subject(in: lines, above: questionAt)
        region = Array(lines[questionAt...footer])
        signature = Array(lines[max(0, first - Self.signatureLookback)...footer])
    }

    // MARK: Grammar

    /// How far above the footer options may be.
    static let optionScan = 24
    /// How far below the last option the footer may be: a hint row and a blank.
    static let footerGap = 3
    /// The extra rows a plan's feedback text may wrap onto.
    static let feedbackWrap = 4
    /// How far above the first option the question may be.
    static let questionScan = 12
    /// How far above the question the dialog's subject may reach.
    static let subjectScan = 20
    static let signatureLookback = 40

    struct Row {
        let index: Int
        let number: Int
        let label: String
    }

    /// `❯ 1. Yes` or `2. No`: the number and the label.
    static func optionRow(_ line: String) -> (number: Int, label: String)? {
        let text = line.trimmingCharacters(in: .whitespaces)
        guard let match = text.wholeMatch(of: /(?:❯\s*)?([0-9]+)\.\s+(.+)/), let number = Int(match.output.1) else {
            return nil
        }
        return (number, String(match.output.2).trimmingCharacters(in: .whitespaces))
    }

    /// The rows numbered 1, 2, … up to the last one. Numbered lines higher up (a plan's steps) are not options.
    static func trailingMenu(_ rows: [Row]) -> [Row] {
        guard var start = rows.indices.last else { return [] }
        while start > 0, rows[start - 1].number == rows[start].number - 1 { start -= 1 }
        return rows[start].number == 1 ? Array(rows[start...]) : []
    }

    /// The nearest line with a `?` above the first option, not crossing a rule.
    static func question(in lines: [String], above first: Int) -> Int? {
        for index in stride(from: first - 1, through: max(0, first - questionScan), by: -1) {
            if isRule(lines[index]) { return nil }
            if lines[index].contains("?") { return index }
        }
        return nil
    }

    /// The dialog's rows between its top border and its question, without inner rules and blank rows.
    static func subject(in lines: [String], above question: Int) -> [String] {
        var rows: [String] = []
        for index in stride(from: question - 1, through: max(0, question - subjectScan), by: -1) {
            let line = lines[index]
            if InputBox.isBareBorder(line) { return rows.reversed() }
            if isBlank(line) || isRule(line) { continue }
            rows.append(line.trimmingCharacters(in: CharacterSet(charactersIn: "☐").union(.whitespaces)))
        }
        // No top border in reach: the rows are the transcript's, not the dialog's.
        return []
    }

    static func isBlank(_ line: String) -> Bool {
        line.allSatisfy(\.isWhitespace)
    }

    /// A line of box-drawing, block-eighth or dash glyphs alone. ASCII `-` and `=` are markdown, not rules.
    static func isRule(_ line: String) -> Bool {
        let glyphs = line.unicodeScalars.filter { !$0.properties.isWhitespace }
        return glyphs.count >= 3
            && glyphs.allSatisfy {
                (0x2500...0x257F).contains($0.value) || (0x2581...0x2594).contains($0.value)
                    || (0x2012...0x2015).contains($0.value)
            }
    }

    /// A multi-question stepper: `☐ Focus area  ☐ Scope  ✔ Submit`.
    static func isStepper(_ line: String) -> Bool {
        line.filter { "☐☒☑✔✅".contains($0) }.count >= 2
    }

    static func isFreeText(_ label: String) -> Bool {
        let label = label.lowercased()
        return label.hasPrefix("type something") || label.hasPrefix("tell claude what to change")
    }

    /// The hint under a plan's feedback row, which stays when the row's placeholder gives way to typed text.
    static func isFeedbackHint(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces).lowercased().hasPrefix("shift+tab to approve with this feedback")
    }

    static func isPointed(_ line: String) -> Bool {
        line.drop(while: \.isWhitespace).hasPrefix("❯")
    }
}

extension Prompt.Family {
    /// The family the footer names. "Enter to confirm" is ordinary wording, so it names the trust prompt only when
    /// that prompt's own words are on screen.
    init?(footer: String, screen: [String]) {
        let footer = footer.lowercased()
        if footer.contains("enter to select") {
            self = .select
        } else if footer.contains("enter to confirm") {
            let trust = screen.contains {
                let line = $0.lowercased()
                return line.contains("is this a project you created or one you trust")
                    || line.contains("yes, i trust this folder")
            }
            guard trust else { return nil }
            self = .trust
        } else if footer.contains("ctrl+g to edit") || footer.contains(".claude/plans/") {
            self = .plan
        } else if footer.contains("tab to amend") {
            self = .permission
        } else {
            return nil
        }
    }
}
