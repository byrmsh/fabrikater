import Foundation
import Testing

@testable import PromptKit

struct PromptTests {
    private func prompt(_ name: String) throws -> Prompt? {
        Prompt(on: Screen(ansi: String(decoding: try Fixture.data(named: "panes/\(name).txt"), as: UTF8.self)))
    }

    @Test func aBashPermissionPromptOffersItsThreeAnswers() throws {
        let prompt = try #require(try prompt("claude--permission-bash"))
        #expect(prompt.family == .permission)
        #expect(prompt.question == "Do you want to proceed?")
        #expect(
            prompt.subject == [
                "Bash command", "mkfifo fixture-fifo", "Create a named pipe (FIFO)",
                "This command requires approval",
            ])
        #expect(prompt.options.map(\.number) == [1, 2, 3])
        #expect(prompt.options.map(\.label) == ["Yes", "Yes, and don’t ask again for: mkfifo fixture-fifo *", "No"])
        #expect(!prompt.confirmsWithEnter)
        #expect(prompt.region.first?.contains("Do you want to proceed?") == true)
        #expect(prompt.region.last?.contains("Esc to cancel") == true)
    }

    @Test func anEditPermissionPromptShowsTheFileWithoutItsRules() throws {
        let prompt = try #require(try prompt("claude--permission-edit"))
        #expect(prompt.family == .permission)
        #expect(prompt.question == "Do you want to create hello.txt?")
        #expect(prompt.subject == ["Create file", "hello.txt", "1 hello"])
        #expect(prompt.options.map(\.label).first == "Yes")
    }

    @Test func aSingleQuestionKeepsDescriptionsAndDropsTheTypedAnswerRow() throws {
        let prompt = try #require(try prompt("claude--select-menu"))
        #expect(prompt.family == .select)
        #expect(prompt.confirmsWithEnter)
        #expect(prompt.question == "Which color theme should the dashboard use?")
        #expect(prompt.subject == ["Color Theme"])
        #expect(prompt.options.map(\.label) == ["Red", "Green", "Blue", "Chat about this"])
        #expect(prompt.options.map(\.number) == [1, 2, 3, 5])
        #expect(prompt.options.first?.description == "A warm, high-energy theme with red as the primary accent color.")
        #expect(prompt.options.last?.description == nil)
    }

    @Test func aPlanApprovalLeavesOutTheFeedbackRow() throws {
        let prompt = try #require(try prompt("claude--plan-approval"))
        #expect(prompt.family == .plan)
        #expect(prompt.question == "Claude has written up a plan and is ready to execute. Would you like to proceed?")
        #expect(prompt.options.map(\.number) == [1, 2, 3])
        #expect(prompt.options.first?.label == "Yes, and use auto mode")
    }

    @Test func theTrustPromptIsKnownByItsOwnWords() throws {
        let prompt = try #require(try prompt("claude--trust-prompt"))
        #expect(prompt.family == .trust)
        #expect(prompt.options.map(\.label) == ["Yes, I trust this folder", "No, exit"])
        let words = "Is this a project you created or one you trust?"
        let screen = Screen(ansi: "Pick one?\n ❯ 1. Yes\n   2. No\n\n Enter to confirm · Esc to cancel")
        #expect(Prompt(on: screen) == nil)
        #expect(Prompt(on: Screen(ansi: "\(words)\n ❯ 1. Yes\n   2. No\n\n Enter to confirm"))?.family == .trust)
    }

    /// A multi-question wizard, menus, sliders and every screen with the input box: nothing to answer with a card.
    @Test(arguments: [
        "claude--wizard-q1", "claude--wizard-submit", "claude--menu-model-picker", "claude--menu-effort-slider--w40",
        "claude--fresh-idle", "claude--done", "claude--working", "claude--draft-wrapped", "claude--send-inflight",
        "claude-lab--transcript-dialog-lookalike--w82", "claude-lab--statusline-3row--w82",
        "claude-lab--popup-slash-all--w82", "codex--approval-exec", "codex--ask-fruit", "grok--permission-rm",
        "grok--ask-color",
    ])
    func declinesScreensItCannotAnswer(_ name: String) throws {
        #expect(try prompt(name) == nil)
    }

    @Test func aPointerOnATypedAnswerRowDeclines() {
        let screen = Screen(
            ansi: "Which one?\n  1. Red\n  2. Blue\n❯ 3. Type something.\n\nEnter to select · Esc to cancel")
        #expect(Prompt(on: screen) == nil)
    }

    @Test func numberedLinesAboveTheMenuAreNotOptions() {
        let screen = Screen(
            ansi: "1. step one\n2. step two\nProceed?\n❯ 1. Yes\n  2. No\n\nEsc to cancel · Tab to amend")
        #expect(Prompt(on: screen)?.options.map(\.label) == ["Yes", "No"])
    }

    @Test func aMenuFarAboveTheFooterIsNotAPrompt() {
        let screen = Screen(
            ansi: "Proceed?\n❯ 1. Yes\n  2. No\n\n\n\n\nlater output\nmore\nEsc to cancel · Tab to amend")
        #expect(Prompt(on: screen) == nil)
    }

    @Test func theSameShapeAskingAboutSomethingElseIsADifferentPrompt() {
        let dialog =
            "\n─────────────\n Bash command\n\n   %@\n\n Do you want to proceed?\n ❯ 1. Yes\n   2. No\n\n Esc to cancel · Tab to amend"
        let ls = Prompt(on: Screen(ansi: dialog.replacing("%@", with: "ls")))
        let rm = Prompt(on: Screen(ansi: dialog.replacing("%@", with: "rm -rf build")))
        #expect(ls != nil && rm != nil)
        #expect(ls != rm)
        #expect(ls == Prompt(on: Screen(ansi: dialog.replacing("%@", with: "ls"))))
    }
}
