import FabrikaterCore
import Foundation
import HerdrKit
import PromptKit
import Testing
import TranscriptKit

@testable import AppModel

@MainActor
struct PromptCardTests {
    /// Serves one screen per read, in order, repeating the last.
    private final class Screens: PaneReader, @unchecked Sendable {
        var screens: [String]
        var error: (any Error)?
        private(set) var reads = 0

        init(_ screens: String...) {
            self.screens = screens
        }

        func screen(of pane: PaneID) async throws -> String {
            defer { reads += 1 }
            if let error { throw error }
            return screens[min(reads, screens.count - 1)]
        }
    }

    private struct NoTranscripts: TranscriptService {
        func claudeTranscript(session: SessionID, bytes: Int) async throws -> Transcript { Transcript() }
    }

    private let permission = Self.screen("claude--permission-bash")
    private let question = Self.screen("claude--select-menu")
    private let wizard = Self.screen("claude--wizard-q1")
    private let working = Self.screen("claude--working")

    private static func screen(_ name: String) -> String {
        String(decoding: (try? Fixture.data(named: "panes/\(name).txt")) ?? Data(), as: UTF8.self)
    }

    private func pane(_ status: AgentStatus = .blocked, agent: AgentKind = .claude, revision: Int = 1) throws
        -> Herd.Pane
    {
        let herd = try Herd(snapshotReply: Fixture.data(named: "snapshot.synthetic.json"))
        var pane = try #require(herd.pane(PaneID("w1:p1")!))
        pane.agentStatus = status
        pane.agent = agent
        pane.revision = revision
        return pane
    }

    private func store(_ screens: Screens, _ control: FakeControl = FakeControl()) -> PromptCardStore {
        PromptCardStore(reader: screens, control: control, sleep: { _ in })
    }

    private func prompt(_ screen: String) throws -> Prompt {
        try #require(Prompt(on: Screen(ansi: screen)))
    }

    @Test func aBlockedPaneShowsThePromptOnItsScreen() async throws {
        let store = store(Screens(permission))
        store.show(try pane(), isOnline: true)
        await store.task?.value
        #expect(store.card == .prompt(try prompt(permission)))
        #expect(store.title == "Permission Needed")
        #expect(store.canAnswer)
    }

    @Test func aPaneThatIsNotBlockedHasNoCardAndIsNotRead() async throws {
        let screens = Screens(permission)
        let store = store(screens)
        store.show(try pane(.working), isOnline: true)
        await store.task?.value
        #expect(store.card == nil)
        #expect(screens.reads == 0)
    }

    @Test func anotherAgentsDialogOffersNoAnswer() async throws {
        let screens = Screens(permission)
        let store = store(screens)
        store.show(try pane(agent: .codex), isOnline: true)
        #expect(store.card == .unknown)
        #expect(store.title == "Waiting for Input")
        #expect(screens.reads == 0)
    }

    @Test(arguments: ["wizard", "working"])
    func aScreenWithoutAPromptItReadsOffersNoAnswer(_ name: String) async throws {
        let store = store(Screens(name == "wizard" ? wizard : working))
        store.show(try pane(), isOnline: true)
        await store.task?.value
        #expect(store.card == .unknown)
    }

    @Test func anUnreadableScreenSaysWhy() async throws {
        let screens = Screens(permission)
        screens.error = HerdrError("ssh failed")
        let store = store(screens)
        store.show(try pane(), isOnline: true)
        await store.task?.value
        #expect(store.card == .unknown)
        #expect(store.notice == "Could not read the pane's screen: ssh failed")
    }

    @Test func theScreenIsReadAgainOnlyWhenThePaneChanges() async throws {
        let screens = Screens(permission, question)
        let store = store(screens)
        store.show(try pane(), isOnline: true)
        await store.task?.value
        store.show(try pane(), isOnline: true)
        await store.task?.value
        #expect(screens.reads == 1)
        store.show(try pane(revision: 2), isOnline: true)
        await store.task?.value
        #expect(store.card == .prompt(try prompt(question)))
    }

    @Test func aPermissionIsAnsweredWithItsDigitWhileTheHostStillSeesThePrompt() async throws {
        let control = FakeControl()
        let store = store(Screens(permission, permission, working), control)
        store.show(try pane(), isOnline: true)
        await store.task?.value
        store.answer(2)
        #expect(store.answering == 2)
        #expect(!store.canAnswer)
        await store.task?.value
        let prompt = try prompt(permission)
        #expect(
            control.performed == [
                [.checked(PromptCardStore.check(prompt), .sendKeys(PaneID("w1:p1")!, [.digit(2)!]))]
            ])
        #expect(store.card == nil)
        #expect(store.answering == nil)
        #expect(store.notice == nil)
    }

    @Test func theHostCheckWantsTheQuestionThroughTheFooterAtTheBottom() throws {
        let check = PromptCardStore.check(try prompt(permission))
        #expect(check.rows.first == "Doyouwanttoproceed?")
        #expect(check.rows.last == "Esctocancel·Tabtoamend·ctrl+etoexplain")
        #expect(check.refusing.isEmpty)
    }

    @Test func aQuestionIsAnsweredWithItsDigitThenEnter() async throws {
        let control = FakeControl()
        let store = store(Screens(question, question, working), control)
        store.show(try pane(), isOnline: true)
        await store.task?.value
        store.answer(3)
        await store.task?.value
        #expect(
            control.performed.first?.first
                == .checked(
                    PromptCardStore.check(try prompt(question)), .sendKeys(PaneID("w1:p1")!, [.digit(3)!, .enter])))
    }

    @Test func aPromptThatChangedBeforeTheAnswerGetsNothingSent() async throws {
        let control = FakeControl()
        let store = store(Screens(permission, question), control)
        store.show(try pane(), isOnline: true)
        await store.task?.value
        store.answer(1)
        await store.task?.value
        #expect(control.performed.isEmpty)
        #expect(store.card == .prompt(try prompt(question)))
        #expect(store.notice == PromptCardStore.changedNotice)
    }

    @Test func theHostRefusingTheAnswerSaysThePromptChanged() async throws {
        let control = FakeControl()
        control.error = HerdrError.screenChanged
        let store = store(Screens(permission), control)
        store.show(try pane(), isOnline: true)
        await store.task?.value
        store.answer(1)
        await store.task?.value
        #expect(store.notice == PromptCardStore.changedNotice)
        #expect(store.canAnswer)
    }

    @Test func aPromptThatStaysAfterTheAnswerSaysSo() async throws {
        let store = store(Screens(permission))
        store.show(try pane(), isOnline: true)
        await store.task?.value
        store.answer(1)
        await store.task?.value
        #expect(store.notice == "Sent “Yes”, but the prompt is still showing.")
        #expect(store.canAnswer)
    }

    @Test func optionsTheCardDoesNotOfferAreNotSent() async throws {
        let control = FakeControl()
        let store = store(Screens(question), control)
        store.show(try pane(), isOnline: true)
        await store.task?.value
        store.answer(4)
        await store.task?.value
        #expect(control.performed.isEmpty)
        #expect(store.answering == nil)
    }

    @Test func offlineNothingCanBeAnswered() async throws {
        let store = store(Screens(permission))
        store.show(try pane(), isOnline: false)
        await store.task?.value
        #expect(store.card != nil)
        #expect(!store.canAnswer)
    }

    @Test func theMainWindowsCardFollowsTheSelection() async throws {
        let screens = Screens(permission)
        let control = FakeControl()
        var herd = try Herd(snapshotReply: Fixture.data(named: "snapshot.synthetic.json"))
        let index = try #require(herd.panes.firstIndex { $0.id == PaneID("w1:p1")! })
        herd.panes[index].agentStatus = .blocked
        let app = AppStore(
            herdUpdates: AsyncStream { $0.finish() }, transcripts: NoTranscripts(), control: FakeControl(),
            screens: screens, answers: control)
        app.apply(.herd(herd))
        app.perform(.selectPane(PaneID("w1:p1")!))
        await app.prompt.task?.value
        #expect(app.prompt.card == .prompt(try prompt(permission)))
        #expect(app.isEnabled(.answerPrompt(1)))
        #expect(app.composer.notice == ComposerStore.blockedNotice)
        app.perform(.selectPane(PaneID("w2:p1")!))
        #expect(app.prompt.card == nil)
    }
}

extension PromptCardTests {
    @Test func theCardSaysWhatThePromptAsksAndOffers() async throws {
        let store = store(Screens(question))
        store.show(try pane(), isOnline: true)
        await store.task?.value
        #expect(store.isShown)
        #expect(store.title == "Question")
        #expect(store.question == "Which color theme should the dashboard use?")
        #expect(store.subject == "Color Theme")
        #expect(store.options.map(\.title) == ["1. Red", "2. Green", "3. Blue", "5. Chat about this"])
        #expect(store.options.first?.detail == "A warm, high-energy theme with red as the primary accent color.")
        #expect(store.options.first?.help == "Press 1 in the pane: Red")
    }

    @Test func theCardWithoutOptionsSaysToAnswerInHerdr() async throws {
        let store = store(Screens(wizard))
        store.show(try pane(), isOnline: true)
        await store.task?.value
        #expect(store.isShown)
        #expect(store.question == PromptCardStore.unknownMessage)
        #expect(store.subject == nil)
        #expect(store.options.isEmpty)
        #expect(store.offersTerminal)
    }
}
