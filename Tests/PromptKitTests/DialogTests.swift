import Foundation
import Testing

@testable import PromptKit

struct DialogTests {
    private func screen(_ name: String) throws -> Screen {
        Screen(ansi: String(decoding: try Fixture.data(named: "panes/\(name).txt"), as: UTF8.self))
    }

    @Test(arguments: [
        ("claude--permission-bash", "Do you want to proceed?"),
        ("claude--permission-edit", "Do you want to create hello.txt?"),
        ("claude--wizard-submit", "Ready to submit your answers?"),
        (
            "claude--plan-approval",
            "Claude has written up a plan and is ready to execute. Would you like to proceed?"
        ),
        ("codex--ask-fruit", "Pick a fruit?"),
        ("grok--ask-color", "Which color theme should the dashboard use?"),
    ])
    func findsTheDialogAndItsQuestion(_ name: String, question: String) throws {
        #expect(Dialog(on: try screen(name))?.question == question)
    }

    @Test(arguments: [
        "claude--select-menu", "claude--wizard-q1", "claude--trust-prompt", "claude--menu-model-picker",
        "claude--menu-effort-slider--w40", "codex--approval-exec", "grok--permission-rm",
    ])
    func findsDialogsWhoseFooterSaysSo(_ name: String) throws {
        #expect(Dialog(on: try screen(name)) != nil)
    }

    /// Idle, working and drafting screens, including a transcript that quotes a dialog above the input box.
    @Test(arguments: [
        "claude--fresh-idle", "claude--done", "claude--working", "claude--draft-wrapped", "claude--send-inflight",
        "claude-lab--transcript-dialog-lookalike--w82", "claude-lab--statusline-3row--w82",
        "claude-lab--popup-slash-all--w82", "codex--fresh-idle", "codex--working", "grok--fresh-idle",
        "grok--working",
    ])
    func findsNoDialogWhenTheInputBoxShows(_ name: String) throws {
        #expect(Dialog(on: try screen(name)) == nil)
    }

    @Test func screensLoseStylingAndCarriageReturns() {
        let screen = Screen(ansi: "\u{1B}[1mBold\u{1B}[0m  \r\nnext\r\n")
        #expect(screen.lines == ["Bold", "next", ""])
    }

    @Test func aQuestionStopsAtARule() {
        let screen = Screen(ansi: "Earlier?\n────────────\n 1. Yes\n 2. No\n Esc to cancel")
        #expect(Dialog(on: screen) == Dialog(question: nil))
    }
}
