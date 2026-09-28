import FabrikaterCore
import HerdrKit
import Testing
import TranscriptKit

@testable import AppModel

@MainActor
struct LiveFollowTests {
    /// Follows each session through a stream the test feeds, counting the follows and the one-off reads.
    private final class FollowedTranscripts: TranscriptService, @unchecked Sendable {
        private(set) var reads = 0
        private(set) var follows = 0
        private var feeds: [AsyncThrowingStream<Transcript, any Error>.Continuation] = []

        func transcript(of log: SessionLog, bytes: Int) async throws -> Transcript {
            reads += 1
            return Transcript()
        }

        func followTranscript(of log: SessionLog, bytes: Int) -> AsyncThrowingStream<Transcript, any Error> {
            follows += 1
            let (stream, feed) = AsyncThrowingStream<Transcript, any Error>.makeStream()
            feeds.append(feed)
            return stream
        }

        /// What the log reads after `count` rows, on the latest follow.
        func grow(to count: Int) {
            feeds.last?.yield(rows(count))
        }

        func endFollow() {
            feeds.last?.finish()
        }
    }

    private let transcripts = FollowedTranscripts()
    private let refactor = PaneID("w1:p1")!

    private func transcript(_ count: Int) -> Transcript { rows(count) }

    private func makeStore() throws -> (AppStore, Herd) {
        let herd = try Herd(snapshotReply: Fixture.data(named: "snapshot.synthetic.json"))
        let store = AppStore(herdUpdates: AsyncStream { $0.finish() }, transcripts: transcripts, control: FakeControl())
        store.apply(.herd(herd))
        return (store, herd)
    }

    /// Lets the load task run until `condition` holds.
    private func settle(until condition: () -> Bool) async {
        for _ in 0..<1000 where !condition() {
            await Task.yield()
        }
    }

    @Test func rowsWrittenToTheLogAppearInTheSelectedConversation() async throws {
        let (store, _) = try makeStore()
        store.perform(.selectPane(refactor))
        await settle { transcripts.follows == 1 }
        transcripts.grow(to: 2)
        await settle { store.conversation.transcript.entries.count == 2 }
        #expect(!store.conversation.isLoading)
        transcripts.grow(to: 3)
        await settle { store.conversation.transcript.entries.count == 3 }
        #expect(store.conversation.transcript == transcript(3))
    }

    @Test func rowsWrittenToTheLogAppearInAPaneWindow() async throws {
        let (store, _) = try makeStore()
        let window = store.paneWindow(refactor)
        await settle { transcripts.follows == 1 }
        transcripts.grow(to: 4)
        await settle { window.conversation.transcript.entries.count == 4 }
        #expect(window.conversation.transcript == transcript(4))
    }

    @Test func aStatusChangeWhileFollowingReadsNothingMore() async throws {
        let (store, initial) = try makeStore()
        store.perform(.selectPane(refactor))
        await settle { transcripts.follows == 1 }
        transcripts.grow(to: 1)
        await settle { !store.conversation.transcript.entries.isEmpty }

        var herd = initial
        let index = try #require(herd.panes.firstIndex { $0.id == refactor })
        herd.panes[index].agentStatus = .done
        store.apply(.herd(herd))
        await settle { transcripts.follows > 1 }
        #expect(transcripts.follows == 1)
        #expect(transcripts.reads == 1)
    }

    @Test func aStatusChangeAfterTheFollowEndedFollowsAgain() async throws {
        let (store, initial) = try makeStore()
        store.perform(.selectPane(refactor))
        await settle { transcripts.follows == 1 }
        transcripts.grow(to: 1)
        transcripts.endFollow()
        await store.conversation.loadTask?.value

        var herd = initial
        let index = try #require(herd.panes.firstIndex { $0.id == refactor })
        herd.panes[index].agentStatus = .done
        store.apply(.herd(herd))
        await settle { transcripts.follows == 2 }
        #expect(transcripts.follows == 2)
        #expect(store.conversation.transcript == transcript(1))
    }
}

/// A conversation of `count` rows.
private func rows(_ count: Int) -> Transcript {
    Transcript(entries: (0..<count).map { TranscriptEntry(id: "e\($0)", role: .assistant, parts: [.text("\($0)")]) })
}
