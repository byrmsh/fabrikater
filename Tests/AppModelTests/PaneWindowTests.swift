import FabrikaterCore
import HerdrKit
import Testing
import TranscriptKit

@testable import AppModel

@MainActor
struct PaneWindowTests {
    /// Answers each session with one entry naming it, counting the loads.
    private final class SessionTranscripts: TranscriptService, @unchecked Sendable {
        private(set) var loads = 0

        func claudeTranscript(session: SessionID, bytes: Int) async throws -> Transcript {
            loads += 1
            return Transcript(entries: [TranscriptEntry(id: "e1", role: .user, parts: [.text(session.rawValue)])])
        }
    }

    private let transcripts = SessionTranscripts()
    private let clipboard = InMemoryClipboard()
    private let refactor = PaneID("w1:p1")!
    private let scratch = PaneID("w2:p1")!

    private func makeStore() throws -> (AppStore, Herd) {
        let herd = try Herd(snapshotReply: Fixture.data(named: "snapshot.synthetic.json"))
        let store = AppStore(
            herdUpdates: AsyncStream { $0.finish() }, transcripts: transcripts, control: FakeControl(),
            clipboard: clipboard)
        store.apply(.herd(herd))
        return (store, herd)
    }

    private func text(of conversation: ConversationStore) -> String? {
        guard case .text(let text, _) = conversation.transcript.entries.first?.parts.first else { return nil }
        return text
    }

    @Test func aWindowShowsItsOwnPaneWhateverTheMainWindowSelects() async throws {
        let (store, _) = try makeStore()
        store.perform(.selectPane(scratch))
        let window = store.paneWindow(refactor)
        await window.conversation.loadTask?.value
        await store.conversation.loadTask?.value

        #expect(window.header?.title == "Synthetic refactor")
        #expect(window.header?.status == .working)
        #expect(text(of: window.conversation) == "00000000-0000-4000-8000-000000000001")
        #expect(text(of: store.conversation) == "00000000-0000-4000-8000-000000000002")
        #expect(window.notice == nil)
    }

    @Test func openInNewWindowNeedsAPaneHerdrHas() throws {
        let (store, _) = try makeStore()
        #expect(!store.isEnabled(.openInNewWindow(nil)))
        #expect(store.isEnabled(.openInNewWindow(refactor)))
        #expect(!store.isEnabled(.openInNewWindow(PaneID("w9:p9")!)))
        store.perform(.selectPane(scratch))
        #expect(store.windowPane(nil) == scratch)
        #expect(store.windowPane(refactor) == refactor)
    }

    @Test func aStatusChangeReloadsTheWindowsConversation() async throws {
        let (store, initial) = try makeStore()
        let window = store.paneWindow(refactor)
        await window.conversation.loadTask?.value
        let loads = transcripts.loads

        store.apply(.herd(initial))
        #expect(transcripts.loads == loads)

        var herd = initial
        let index = try #require(herd.panes.firstIndex { $0.id == refactor })
        herd.panes[index].agentStatus = .done
        store.apply(.herd(herd))
        await window.conversation.loadTask?.value
        #expect(transcripts.loads == loads + 1)
        #expect(window.header?.status == .done)
    }

    @Test func aRenameReachesTheWindowsTitle() throws {
        let (store, _) = try makeStore()
        let window = store.paneWindow(refactor)
        store.perform(.renamePane(refactor))
        store.perform(.commitRename(refactor, "Helper"))
        #expect(window.header?.title == "Helper")
    }

    @Test func aVanishedPaneKeepsItsLastConversationAndSaysSo() async throws {
        let (store, initial) = try makeStore()
        let window = store.paneWindow(refactor)
        await window.conversation.loadTask?.value

        var herd = initial
        herd.panes.removeAll { $0.id == refactor }
        store.apply(.herd(herd))
        #expect(window.notice == "This pane is no longer in Herdr.")
        #expect(window.header?.title == "Synthetic refactor")
        #expect(text(of: window.conversation) == "00000000-0000-4000-8000-000000000001")

        store.apply(.herd(initial))
        #expect(window.notice == nil)
    }

    @Test func aWindowOpenedBeforeTheFirstHerdWaitsForIt() throws {
        let store = AppStore(herdUpdates: AsyncStream { $0.finish() }, transcripts: transcripts, control: FakeControl())
        let window = store.paneWindow(refactor)
        #expect(window.notice == nil)
        #expect(window.header == nil)
        store.apply(.herd(try Herd(snapshotReply: Fixture.data(named: "snapshot.synthetic.json"))))
        #expect(window.header?.title == "Synthetic refactor")
    }

    @Test func copyInAWindowCopiesItsOwnConversation() async throws {
        let (store, _) = try makeStore()
        store.perform(.selectPane(scratch))
        let window = store.paneWindow(refactor)
        await window.conversation.loadTask?.value
        #expect(window.isEnabled(.copyMessage("e1")))
        window.perform(.copyMessage("e1"))
        #expect(clipboard.text == "00000000-0000-4000-8000-000000000001")
        #expect(!window.isEnabled(.send))
    }

    @Test func aClosedWindowIsLetGo() async throws {
        var list = PaneWindowList()
        var window: PaneWindowStore? = PaneWindowStore(
            paneID: refactor, transcripts: transcripts, clipboard: clipboard)
        list.add(try #require(window))
        #expect(list.stores.count == 1)
        window = nil
        #expect(list.stores.isEmpty)
    }
}
