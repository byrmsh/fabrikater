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
        private(set) var loads = 0

        func claudeTranscript(session: SessionID) async throws -> Transcript {
            loads += 1
            if let error { throw error }
            return transcript
        }
    }

    private let transcripts = FakeTranscripts()
    private let scratch = PaneID("w2:p1")!
    private let codex = PaneID("w1:pB")!

    private func makeStore() throws -> (AppStore, Herd) {
        let herd = try Herd(snapshotReply: Fixture.data(named: "snapshot.synthetic.json"))
        let store = AppStore(herdUpdates: AsyncStream { $0.finish() }, transcripts: transcripts)
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
        let store = AppStore(herdUpdates: AsyncStream { $0.finish() }, transcripts: transcripts)
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
        #expect(store.conversation.message == "Conversations from Codex cannot be shown yet.")
        #expect(!store.isEnabled(.reloadConversation))
        store.perform(.selectPane(PaneID("w1:pA")!))
        #expect(store.conversation.message == "This pane runs a shell, not an agent.")
        #expect(transcripts.loads == 0)
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

    @Test func aStatusChangeOfTheSelectedPaneReloadsItsConversation() async throws {
        let (store, initial) = try makeStore()
        var herd = initial
        store.perform(.selectPane(scratch))
        await store.conversation.loadTask?.value
        store.apply(.herd(herd))
        #expect(transcripts.loads == 1)

        let index = try #require(herd.panes.firstIndex { $0.id == scratch })
        herd.panes[index].agentStatus = .working
        store.apply(.herd(herd))
        await store.conversation.loadTask?.value
        #expect(transcripts.loads == 2)
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
}
