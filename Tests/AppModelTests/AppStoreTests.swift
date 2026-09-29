import FabrikaterCore
import HerdrKit
import Testing
import TranscriptKit

@testable import AppModel

@MainActor
struct AppStoreTests {
    /// Returns `transcript` or throws `error`, counting the loads.
    private final class FakeTranscripts: TranscriptService, @unchecked Sendable {
        var transcript = Transcript(entries: [TranscriptEntry(id: "e1", role: .user, parts: [.text("hi")])])
        var error: (any Error)?
        /// Set to answer the quick window with a clipped transcript, as a long log would.
        var quickIsClipped = false
        private(set) var windows: [Int] = []
        var loads: Int { windows.count }

        func transcript(of log: SessionLog, bytes: Int) async throws -> Transcript {
            windows.append(bytes)
            if let error { throw error }
            return bytes == TranscriptWindow.quick && quickIsClipped ? Transcript(isClipped: true) : transcript
        }
    }

    private let transcripts = FakeTranscripts()

    /// Lets the load task run until `condition` holds.
    private func settle(until condition: () -> Bool) async {
        for _ in 0..<1000 where !condition() {
            await Task.yield()
        }
    }
    private let control = FakeControl()
    private let scratch = PaneID("w2:p1")!
    private let codex = PaneID("w1:pB")!

    private func makeStore() throws -> (AppStore, Herd) {
        let herd = try Herd(snapshotReply: Fixture.data(named: "snapshot.synthetic.json"))
        let store = AppStore(herdUpdates: AsyncStream { $0.finish() }, transcripts: transcripts, control: control)
        store.apply(.herd(herd))
        return (store, herd)
    }

    @Test func aHerdUpdateFillsTheSidebar() throws {
        let (store, _) = try makeStore()
        #expect(store.connection == .connected)
        #expect(store.sections.count == 2)
    }

    @Test func aFailedReadKeepsTheLastHerdAndSaysItIsStale() throws {
        let (store, _) = try makeStore()
        store.apply(.failed("offline"))
        #expect(store.connection == .stale("offline"))
        #expect(store.sections.count == 2)
    }

    @Test func aFailedReadWithNothingLoadedSaysOfflineWithoutClaimingAKnownState() {
        let store = AppStore(herdUpdates: AsyncStream { $0.finish() }, transcripts: transcripts, control: control)
        store.apply(.failed("ssh failed: no route to host"))
        #expect(store.connection == .offline("ssh failed: no route to host"))
        #expect(store.connection.title == "Offline")
        #expect(store.connection.emptySidebar == EmptySidebar(title: "Offline", detail: "ssh failed: no route to host"))
    }

    @Test func selectingAClaudePaneLoadsItsConversation() async throws {
        let (store, _) = try makeStore()
        store.perform(.selectPane(scratch))
        #expect(
            store.header
                == PaneHeader(title: "Scratch", location: "fabrikater-test › scratch", agent: "Claude", status: .done))
        #expect(store.conversation.isLoading)
        await store.conversation.loadTask?.value
        #expect(store.conversation.transcript == transcripts.transcript)
        #expect(!store.conversation.isLoading)
        #expect(store.conversation.message == nil)
    }

    @Test func aPaneWithoutAReadableLogExplainsWhy() throws {
        let (store, _) = try makeStore()
        store.perform(.selectPane(codex))
        #expect(store.conversation.message == "Herdr has not reported a session for this pane yet.")
        #expect(!store.isEnabled(.reloadConversation))
        #expect(store.layout.detail == .conversation)
        store.perform(.selectPane(PaneID("w1:pA")!))
        #expect(store.conversation.message == "This pane runs a shell, not an agent.")
        #expect(transcripts.loads == 0)
    }

    @Test func aPaneWithoutAConversationOpensInTheTerminalAndKeepsTheChoice() throws {
        let (store, _) = try makeStore()
        store.perform(.selectPane(scratch))
        #expect(store.layout.detail == .conversation)
        store.perform(.selectPane(PaneID("w1:pA")!))
        #expect(store.layout.detail == .terminal)
        #expect(!store.isEnabled(.toggleTerminal))
        #expect(store.isChecked(.toggleTerminal) == true)
        store.perform(.selectPane(scratch))
        #expect(store.layout.detail == .conversation)
        #expect(store.isEnabled(.toggleTerminal))
    }

    @Test func aFailedReloadKeepsTheTranscriptAndShowsTheError() async throws {
        let (store, _) = try makeStore()
        store.perform(.selectPane(scratch))
        await store.conversation.loadTask?.value
        transcripts.error = TranscriptError.noLog
        store.perform(.reloadConversation)
        await store.conversation.loadTask?.value
        #expect(store.conversation.transcript == transcripts.transcript)
        #expect(store.conversation.message == TranscriptError.noLog.description)
    }

    @Test func aStatusChangeOfAPaneWhoseLogIsNotFollowedReloadsItsConversation() async throws {
        let (store, initial) = try makeStore()
        var herd = initial
        store.perform(.selectPane(scratch))
        await store.conversation.loadTask?.value
        store.apply(.herd(herd))
        #expect(transcripts.windows == [TranscriptWindow.quick, TranscriptWindow.full])

        let index = try #require(herd.panes.firstIndex { $0.id == scratch })
        herd.panes[index].agentStatus = .working
        store.apply(.herd(herd))
        await store.conversation.loadTask?.value
        #expect(transcripts.loads == 3)
    }

    @Test func nextAndPreviousWalkTheSidebarAndWrap() throws {
        let (store, _) = try makeStore()
        store.perform(.selectNextPane)
        #expect(store.selection?.rawValue == "w1:p1")
        store.perform(.selectPreviousPane)
        #expect(store.selection?.rawValue == "w2:p1")
        store.perform(.selectNextPane)
        #expect(store.selection?.rawValue == "w1:p1")
        store.perform(.selectNextPane)
        #expect(store.selection?.rawValue == "w1:pA")
    }

    @Test func aLongLogShowsTheQuickWindowFirstThenTheFullOne() async throws {
        let (store, _) = try makeStore()
        transcripts.quickIsClipped = true
        store.perform(.selectPane(scratch))
        await store.conversation.loadTask?.value
        #expect(transcripts.windows == [TranscriptWindow.quick, TranscriptWindow.full])
        #expect(store.conversation.transcript == transcripts.transcript)
    }

    @Test func aShortLogShowsTheQuickWindowWithoutASpinnerWhileTheFollowStarts() async throws {
        let (store, _) = try makeStore()
        store.perform(.selectPane(scratch))
        await settle { store.conversation.transcript == transcripts.transcript }
        #expect(!store.conversation.isLoading)
        await store.conversation.loadTask?.value
        #expect(transcripts.windows == [TranscriptWindow.quick, TranscriptWindow.full])
    }

    @Test func goingBackToAPaneShowsItsCachedConversationAtOnce() async throws {
        let (store, _) = try makeStore()
        store.perform(.selectPane(scratch))
        await store.conversation.loadTask?.value
        store.perform(.selectPane(codex))
        store.perform(.selectPane(scratch))
        #expect(store.conversation.transcript == transcripts.transcript)
        #expect(store.conversation.isLoading)
        await store.conversation.loadTask?.value
        #expect(transcripts.windows == [TranscriptWindow.quick, TranscriptWindow.full, TranscriptWindow.full])
    }

    @Test func herdrFocusFollowsOnlyTheSettledSelection() async throws {
        let (store, _) = try makeStore()
        store.perform(.selectNextPane)
        store.perform(.selectNextPane)
        store.perform(.selectPane(scratch))
        await store.focusTask?.value
        #expect(control.performed == [[.focus(scratch)]])
    }

    @Test func sendingDeliversThePromptAndClearsTheDraft() async throws {
        let (store, _) = try makeStore()
        #expect(!store.isEnabled(.send))
        store.perform(.selectPane(scratch))
        await store.focusTask?.value
        store.composer.draft = "  hello  "
        #expect(store.isEnabled(.send))
        store.perform(.send)
        #expect(store.composer.isSending)
        await store.composer.sendTask?.value
        #expect(control.performed.last == HerdrRequest.prompt("hello", to: scratch))
        #expect(store.composer.draft.isEmpty)
        #expect(!store.composer.isSending)
    }

    @Test func aFailedSendKeepsTheDraftAndShowsWhy() async throws {
        let (store, _) = try makeStore()
        store.perform(.selectPane(scratch))
        store.composer.draft = "hello"
        control.error = SendPolicy.Refusal.paneMissing
        store.perform(.send)
        await store.composer.sendTask?.value
        #expect(store.composer.draft == "hello")
        #expect(store.composer.error == SendPolicy.Refusal.paneMissing.description)
    }

    @Test func textTypedDuringASendStaysAndAFailureStaysWithItsPane() async throws {
        let (store, _) = try makeStore()
        store.perform(.selectPane(scratch))
        store.composer.draft = "first"
        store.perform(.send)
        store.composer.draft = "first and more"
        await store.composer.sendTask?.value
        #expect(store.composer.draft == " and more")

        control.error = SendPolicy.Refusal.paneMissing
        store.composer.draft = "second"
        store.perform(.send)
        store.perform(.selectPane(codex))
        #expect(!store.composer.isSending)
        await store.composer.sendTask?.value
        #expect(store.composer.error == nil)
        store.perform(.selectPane(scratch))
        #expect(store.composer.error == SendPolicy.Refusal.paneMissing.description)
    }

    @Test func aBlockedPaneSaysItIsWaitingAndTakesNoPrompt() throws {
        let (store, _) = try makeStore()
        store.perform(.selectPane(codex))
        store.composer.draft = "1"
        #expect(store.composer.notice == ComposerStore.blockedNotice)
        #expect(!store.isEnabled(.send))
        store.perform(.selectPane(scratch))
        #expect(store.composer.notice == nil)
    }

    @Test func theKeyBarSendsOneKeyAndLeavesTheDraft() async throws {
        let (store, _) = try makeStore()
        #expect(!store.isEnabled(.sendKey(.escape)))
        store.perform(.selectPane(scratch))
        await store.focusTask?.value
        store.composer.draft = "keep me"
        #expect(PaneKey.allCases.allSatisfy { store.isEnabled(.sendKey($0)) })
        store.perform(.sendKey(.shiftTab))
        await store.composer.keyTask?.value
        #expect(control.performed.last == [.sendKeys(scratch, [.shiftTab])])
        #expect(store.composer.draft == "keep me")
    }

    @Test func whileADialogWaitsOnlyTheKeysThatCancelItAreOn() throws {
        let (store, _) = try makeStore()
        store.perform(.selectPane(codex))
        #expect(PaneKey.allCases.filter { store.isEnabled(.sendKey($0)) } == [.escape, .ctrlC])
        store.apply(.failed("offline"))
        #expect(!store.isEnabled(.sendKey(.escape)))
    }

    @Test func aFailedKeyShowsWhy() async throws {
        let (store, _) = try makeStore()
        store.perform(.selectPane(scratch))
        control.error = SendPolicy.Refusal.paneMissing
        store.perform(.sendKey(.enter))
        await store.composer.keyTask?.value
        #expect(store.composer.error == SendPolicy.Refusal.paneMissing.description)
    }

    @Test func draftsArePerPaneAndSendingStopsWhileOffline() throws {
        let (store, _) = try makeStore()
        store.perform(.selectPane(scratch))
        store.composer.draft = "for scratch"
        store.perform(.selectPane(codex))
        #expect(store.composer.draft.isEmpty)
        store.perform(.selectPane(scratch))
        #expect(store.composer.draft == "for scratch")
        store.apply(.failed("offline"))
        #expect(!store.isEnabled(.send))
        #expect(store.composer.disabledReason != nil)
    }

    @Test func aSendThatFailedWhileTheHostWasDownIsNeverResentAfterReconnecting() async throws {
        let (store, herd) = try makeStore()
        store.perform(.selectPane(scratch))
        store.composer.draft = "hello"
        control.error = HerdrError("ssh failed: connection lost")
        store.perform(.send)
        await store.composer.sendTask?.value
        store.apply(.failed("ssh failed: connection lost"))
        store.perform(.selectPane(codex))

        control.error = nil
        store.apply(.herd(herd))
        let typed = control.performed.flatMap { $0 }.filter { if case .focus = $0 { false } else { true } }
        #expect(typed.isEmpty)
        #expect(store.composer.draft.isEmpty)
        store.perform(.selectPane(scratch))
        #expect(store.composer.draft == "hello")
    }
}

/// Records the requests it performs, or throws `error`.
final class FakeControl: HerdrControl, @unchecked Sendable {
    var error: (any Error)?
    private(set) var performed: [[HerdrRequest]] = []

    func perform(_ requests: [HerdrRequest]) async throws {
        if let error { throw error }
        performed.append(requests)
    }
}
