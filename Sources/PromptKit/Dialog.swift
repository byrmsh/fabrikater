// Footer phrases from AltanS/collie@b7ddc17 web/src/lib/harness/claude/markers.ts (`classifyFooter`) and the Codex and
// Grok adapters described in docs/parsing.md 4.4 (MIT).
import Foundation

/// A dialog an agent shows in place of its input box: a permission prompt, a question, a picker or a menu.
/// While one is up, typed text answers it instead of reaching the agent as a prompt.
public struct Dialog: Equatable, Sendable {
    /// The question the dialog asks, when one is on screen.
    public let question: String?

    public init(question: String?) {
        self.question = question
    }

    /// The dialog at the bottom of `screen`, or nil when the screen shows none this check knows.
    ///
    /// It reads only the footer, the last few non-blank lines, where every agent prints its dialog's key hints; a
    /// transcript quoting those words higher up does not count.
    public init?(on screen: Screen) {
        let footer = screen.lastNonBlank(Self.footerLines)
        guard footer.contains(where: Self.isDialogHint) else { return nil }
        question = Self.question(on: screen)
    }

    static let footerLines = 3

    /// Lowercased key hints that only a dialog prints. The input box's own hints (`esc to interrupt`,
    /// `? for shortcuts`) are not among them.
    static let hints = [
        // Claude Code: AskUserQuestion, permission, plan approval, pickers and menus, and the answers review.
        "enter to select", "tab to amend", "ctrl+g to edit", ".claude/plans/", "esc to cancel",
        "enter to confirm", "type to filter", "ready to submit your answers?",
        // Codex: approval, trust and question cards.
        "press enter to confirm", "press enter to continue", "enter to submit",
        // Grok: permission, questions and plan approval.
        "ctrl+c:cancel", "enter:submit", "shift+x:dismiss", "q:quit plan", "a:approve",
    ]

    static func isDialogHint(_ line: String) -> Bool {
        let line = line.lowercased()
        return hints.contains { line.contains($0) }
    }

    /// The nearest line above the footer that asks something, within the dialog's usual height.
    static func question(on screen: Screen) -> String? {
        let nonBlank = screen.lines.map(Self.trimmed).filter { !$0.isEmpty }
        for line in nonBlank.dropLast().suffix(Self.questionLines).reversed() {
            if line.allSatisfy({ "─━═-".contains($0) }) { return nil }
            if line.hasSuffix("?") { return line }
        }
        return nil
    }

    static let questionLines = 16

    /// A line without the box-drawing borders and markers agents draw around dialog text.
    static func trimmed(_ line: String) -> String {
        line.trimmingCharacters(in: CharacterSet(charactersIn: "│┃❯›>").union(.whitespaces))
    }
}
