import FabrikaterCore
import HerdrKit
import Testing
import TranscriptKit

@testable import AppModel

@MainActor
struct CopyTests {
    private struct FixedTranscripts: TranscriptService {
        let transcript: Transcript

        func transcript(of log: SessionLog, bytes: Int) async throws -> Transcript { transcript }
    }

    private let clipboard = InMemoryClipboard()
    private let transcript = Transcript(entries: [
        TranscriptEntry(id: "u1", role: .user, parts: [.text("Rename it")]),
        TranscriptEntry(id: "a1", role: .assistant, parts: [.text("Done.")]),
    ])

    private func makeStore() async throws -> AppStore {
        let store = AppStore(
            herdUpdates: AsyncStream { $0.finish() }, transcripts: FixedTranscripts(transcript: transcript),
            control: FakeControl(), clipboard: clipboard)
        store.apply(.herd(try Herd(snapshotReply: Fixture.data(named: "snapshot.synthetic.json"))))
        store.perform(.selectPane(PaneID("w2:p1")!))
        await store.conversation.loadTask?.value
        return store
    }

    @Test func copiesTheConversation() async throws {
        let store = try await makeStore()
        #expect(store.isEnabled(.copyConversation))
        store.perform(.copyConversation)
        #expect(clipboard.text == Transcript.markdown(of: transcript.entries))
    }

    @Test func copiesOneMessageWithoutItsHeading() async throws {
        let store = try await makeStore()
        store.perform(.copyMessage("a1"))
        #expect(clipboard.text == "Done.")
    }

    @Test func anUnknownMessageCopiesNothing() async throws {
        let store = try await makeStore()
        #expect(!store.isEnabled(.copyMessage("gone")))
        store.perform(.copyMessage("gone"))
        #expect(clipboard.text == nil)
    }

    @Test func withNoConversationCopyIsDisabled() throws {
        let store = AppStore(
            herdUpdates: AsyncStream { $0.finish() }, transcripts: FixedTranscripts(transcript: transcript),
            control: FakeControl(), clipboard: clipboard)
        #expect(!store.isEnabled(.copyConversation))
        store.perform(.copyConversation)
        #expect(clipboard.text == nil)
    }
}
