import Foundation
import Testing

@testable import PromptKit

struct InputBoxTests {
    private func screen(_ name: String) throws -> Screen {
        Screen(ansi: String(decoding: try Fixture.data(named: "panes/\(name).txt"), as: UTF8.self))
    }

    private func box(_ draft: String) -> InputBox? {
        InputBox(on: Screen(ansi: "earlier output\n──────────\n❯ \(draft)\n──────────\n  statusline\n"))
    }

    /// Idle and working screens, a labelled top border, a statusline drawing its own `❯`, and a popup above the box.
    @Test(arguments: [
        "claude--fresh-idle", "claude--working", "claude-lab--statusline-3row--w82", "claude--send-inflight",
    ])
    func findsTheBox(_ name: String) throws {
        let box = try #require(InputBox(on: try screen(name)))
        #expect(InputBox.isTopBorder(try #require(box.rows.first)))
        #expect(InputBox.isBareBorder(try #require(box.rows.last)))
        #expect(InputBox.isPromptRow(box.rows[1]))
    }

    @Test(
        arguments: [
            ("claude--fresh-idle", nil),
            ("claude--working", nil),
            ("claude--send-inflight", "/rename"),
            ("claude-lab--statusline-3row--w82", nil),
            (
                "claude--draft-wrapped",
                "this stranded draft is long enough that Claude soft-wraps it onto several lines inside the input "
                    + "box which is exactly the case that used to stay visible"
            ),
        ] as [(String, String?)])
    func readsTheDraft(_ name: String, draft: String?) throws {
        #expect(try #require(InputBox(on: try screen(name))).draft == draft)
    }

    /// Claude paints a suggested next prompt faint in an empty box; it is not a draft.
    @Test func aFaintSuggestionIsNoDraft() throws {
        let box = try #require(InputBox(on: try screen("claude--done")))
        #expect(box.draft == nil)
        #expect(box.rows[1].contains("cat hello.txt to verify"))
        #expect(!box.carries("cat hello.txt to verify"))
    }

    @Test func aColourIsNotFaint() throws {
        let screen = Screen(ansi: "──────────\n❯ \u{1B}[38;2;153;153;153mreal draft\u{1B}[0m\n──────────\n")
        #expect(InputBox(on: screen)?.draft == "real draft")
    }

    /// Dialogs replace the box, and their pointer row stops the search.
    @Test(arguments: [
        "claude--permission-bash", "claude--permission-edit", "claude--plan-approval", "claude--select-menu",
        "claude--trust-prompt", "claude--wizard-q1", "claude--wizard-submit", "claude--menu-model-picker",
    ])
    func findsNoBoxUnderADialog(_ name: String) throws {
        #expect(InputBox(on: try screen(name)) == nil)
    }

    @Test func aNumberedOptionBelowABoxIsADialog() {
        let screen = Screen(ansi: "──────────\n❯ \n──────────\n Pick one?\n❯ 1. Yes\n  2. No\n")
        #expect(InputBox(on: screen) == nil)
    }

    @Test func carriesTheSentTextWhitespaceAside() throws {
        let box = try #require(box("fix the parser and"))
        #expect(box.carries("fix the parser and"))
        #expect(box.carries("fix the\nparser and "))
        #expect(!box.carries("fix the parser and run the tests"))
        #expect(!box.carries("fix the parser"))
        #expect(try #require(self.box("")).carries("") == false)
    }

    @Test func carriesALongPasteAsItsPlaceholder() throws {
        let threeLines = "one\ntwo\nthree\nfour"
        #expect(try #require(box("[Pasted text #2 +3 lines]")).carries(threeLines))
        #expect(!(try #require(box("[Pasted text #2 +4 lines]")).carries(threeLines)))
        #expect(!(try #require(box("[Pasted text #1]")).carries("short")))
        #expect(try #require(box("[Pasted text #1]")).carries(String(repeating: "x", count: 800)))
    }

    @Test func theQueuedMessagesHintIsNoDraft() {
        #expect(box("Press up to edit queued messages")?.draft == nil)
    }
}
