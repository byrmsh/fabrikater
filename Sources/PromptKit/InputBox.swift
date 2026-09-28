// Ported from AltanS/collie@b7ddc17 (MIT): web/src/lib/harness/claude/chrome.ts (`locateInputBox`,
// `extractInputDraft`, ghost text), web/src/lib/harness/claude/markers.ts (border shapes) and
// web/src/lib/harness/claude/paste.ts (the paste placeholder), simplified as docs/parsing.md 4.4 describes.
import Foundation

/// Claude Code's input box at the bottom of the screen, where typed text lands:
///
///     ──────────── label ──     top border, bare or labelled
///     ❯ the draft               the prompt row (`!` in shell mode)
///       wrapped on              continuation rows
///     ─────────────────────     bottom border, bare
///       statusline rows         anything below, up to `tailLines`
///
/// A screen whose lowest frame row is a dialog's pointer (`❯ 1. Yes`) has no input box: the dialog owns the keys.
public struct InputBox: Equatable, Sendable {
    /// The box as shown, from its top border to its bottom border.
    public let rows: [String]
    /// The text in the box, wrapped rows joined with a space, or nil when it is empty or shows only a suggestion.
    public let draft: String?

    public init?(on screen: Screen) {
        let lines = screen.lines
        guard let end = lines.lastIndex(where: { !Self.isBlank($0) }) else { return nil }

        // The lowest frame row must be the bottom border. A statusline may draw a `❯` or a labelled rule of its
        // own; those are stepped over, but only just under the border.
        var bottom: Int?
        var stepped: [Int] = []
        for index in stride(from: end, through: max(0, end - Self.tailLines), by: -1) {
            let line = lines[index]
            guard Self.isFrameRow(line) else { continue }
            if Self.isBareBorder(line) {
                bottom = index
                break
            }
            if Self.isOption(line) { return nil }
            stepped.append(index)
        }
        guard let bottom, stepped.allSatisfy({ $0 - bottom <= Self.statusLines }) else { return nil }

        // Up from the border to the prompt row, crossing only wrapped text, then the top border right above it.
        var prompt: Int?
        for index in stride(from: bottom - 1, through: max(0, bottom - Self.draftLines), by: -1) {
            if Self.isPromptRow(lines[index]) {
                prompt = index
                break
            }
            if Self.isFrameRow(lines[index]) { return nil }
        }
        guard let prompt, prompt > 0, Self.isTopBorder(lines[prompt - 1]) else { return nil }

        rows = Array(lines[(prompt - 1)...bottom])
        let draft = Self.text(lines[prompt..<bottom])
        let unfaint = screen.unfaint.count == lines.count ? Self.text(screen.unfaint[prompt..<bottom]) : draft
        // A suggestion is drawn faint and typing replaces it, so a box whose text is all faint is empty.
        self.draft = draft.isEmpty || unfaint.isEmpty || Self.placeholders.contains(draft) ? nil : draft
    }

    /// True when the box shows `sent` and nothing else: the same characters, whitespace aside (the box wraps at
    /// word boundaries and trims), or Claude's placeholder for a long paste of the same number of lines.
    public func carries(_ sent: String) -> Bool {
        guard let draft else { return false }
        let shown = draft.filter { !$0.isWhitespace }
        let wanted = sent.filter { !$0.isWhitespace }
        guard !wanted.isEmpty else { return false }
        if shown == wanted { return true }
        guard let token = shown.wholeMatch(of: /\[Pastedtext#[0-9]+(?:\+([0-9]+)lines)?\]/) else { return false }
        let newlines = sent.filter(\.isNewline).count
        if let lines = token.output.1 { return Int(lines) == newlines }
        return newlines == 0 && sent.count >= Self.collapsedPasteLength
    }

    /// How far below the last non-blank line the bottom border may be: Claude's completion popup is the tallest
    /// thing it draws under the box.
    public static let tailLines = 60
    /// How far under the border a statusline's own `❯` or labelled rule may sit.
    static let statusLines = 8
    /// How many rows a wrapped draft may take.
    static let draftLines = 100
    /// Claude inserts shorter single-line pastes literally, so a placeholder for one is someone else's.
    static let collapsedPasteLength = 700
    /// Text Claude draws in an empty box that is not a draft.
    static let placeholders: Set<String> = ["Press up to edit queued messages"]

    private static func text(_ rows: ArraySlice<String>) -> String {
        var parts: [String] = []
        for (offset, row) in rows.enumerated() {
            var row = row.trimmingCharacters(in: .whitespaces)
            if offset == 0 { row = String(row.dropFirst()).trimmingCharacters(in: .whitespaces) }
            if !row.isEmpty { parts.append(row) }
        }
        return parts.joined(separator: " ")
    }

    static func isBlank(_ line: String) -> Bool {
        line.allSatisfy(\.isWhitespace)
    }

    /// `❯`, or shell mode's `!` followed by a space or nothing.
    static func isPromptRow(_ line: String) -> Bool {
        let head = line.drop(while: \.isWhitespace)
        if head.hasPrefix("❯") { return true }
        guard head.hasPrefix("!") else { return false }
        return head.dropFirst().first?.isWhitespace ?? true
    }

    /// A row that belongs to a box's or a dialog's frame: a border shape, or a `❯`-led row.
    static func isFrameRow(_ line: String) -> Bool {
        let head = line.drop(while: \.isWhitespace)
        return head.hasPrefix("❯") || isTopBorder(line)
    }

    /// A dialog's numbered option: `1. Yes`, `❯ 2. No`.
    static func isOption(_ line: String) -> Bool {
        line.firstMatch(of: /^\s*❯\s*[0-9]+\.\s+\S/) != nil
    }

    static func isBareBorder(_ line: String) -> Bool {
        let rule = line.trimmingCharacters(in: .whitespaces)
        return rule.count >= minimumBorder && rule.allSatisfy { $0 == "─" }
    }

    /// A bare border, or `─` runs around a label: `──── fast mode ─`.
    static func isTopBorder(_ line: String) -> Bool {
        let rule = line.trimmingCharacters(in: .whitespaces)
        guard rule.count >= minimumBorder, rule.hasPrefix("─"), rule.hasSuffix("─") else { return false }
        return isBareBorder(rule) || rule.contains { !"─━═-".contains($0) && !$0.isWhitespace }
    }

    static let minimumBorder = 8
}
