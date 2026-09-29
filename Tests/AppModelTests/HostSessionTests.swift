import FabrikaterCore
import HerdrKit
import Testing
import TranscriptKit

@testable import AppModel

@MainActor
struct HostSessionTests {
    /// Follows every log through a stream that stays open until the reader lets go, counting the follows still open.
    private final class OpenFollows: TranscriptService, @unchecked Sendable {
        private(set) var started = 0
        private(set) var ended = 0

        var open: Int { started - ended }

        func transcript(of log: SessionLog, bytes: Int) async throws -> Transcript { Transcript() }

        func followTranscript(of log: SessionLog, bytes: Int) -> AsyncThrowingStream<FollowUpdate, any Error> {
            started += 1
            let (stream, feed) = AsyncThrowingStream<FollowUpdate, any Error>.makeStream()
            feed.onTermination = { [weak self] _ in Task { @MainActor in self?.ended += 1 } }
            return stream
        }
    }

    /// A herd feed that stays open until the store lets go of it.
    private final class OpenFeed: @unchecked Sendable {
        private(set) var ended = false
        private(set) var feed: AsyncStream<HerdUpdate>.Continuation?

        func updates() -> AsyncStream<HerdUpdate> {
            let (stream, feed) = AsyncStream<HerdUpdate>.makeStream()
            feed.onTermination = { [weak self] _ in Task { @MainActor in self?.ended = true } }
            self.feed = feed
            return stream
        }
    }

    private let refactor = PaneID("w1:p1")!

    private func herd() throws -> Herd {
        try Herd(snapshotReply: Fixture.data(named: "snapshot.synthetic.json"))
    }

    private func settle(until condition: () -> Bool) async {
        for _ in 0..<1000 where !condition() {
            await Task.yield()
        }
    }

    @Test func connectingReplacesTheStoreWithOneForTheNewHost() {
        var hosts: [String] = []
        var stores: [AppStore] = []
        let preferences = PreferencesStore(connectedHost: "arch")
        let session = HostSession(preferences: preferences) { host in
            hosts.append(host)
            let store = AppStore(
                herdUpdates: AsyncStream { $0.finish() }, transcripts: OpenFollows(), control: FakeControl(), host: host
            )
            stores.append(store)
            return store
        }
        #expect(hosts == ["arch"])
        preferences.setHostText("devbox")
        preferences.connect()
        #expect(hosts == ["arch", "devbox"])
        #expect(session.store === stores[1])
        #expect(stores[0].isClosed)
        #expect(!stores[1].isClosed)
    }

    @Test func closingEndsTheHerdFeedAndRun() async throws {
        let feed = OpenFeed()
        let store = AppStore(herdUpdates: feed.updates(), transcripts: OpenFollows(), control: FakeControl())
        let run = Task { await store.run() }
        feed.feed?.yield(.herd(try herd()))
        await settle { store.connection == .connected }
        store.close()
        await run.value
        await settle { feed.ended }
        #expect(feed.ended)
    }

    @Test func closingBeforeRunLeavesNothingToRun() async {
        let feed = OpenFeed()
        let store = AppStore(herdUpdates: feed.updates(), transcripts: OpenFollows(), control: FakeControl())
        store.close()
        await store.run()
        #expect(store.updatesTask == nil)
        await settle { feed.ended }
        #expect(feed.ended)
    }

    @Test func closingStopsEveryFollowAndClosesTheWindows() async throws {
        let transcripts = OpenFollows()
        let store = AppStore(herdUpdates: AsyncStream { $0.finish() }, transcripts: transcripts, control: FakeControl())
        store.apply(.herd(try herd()))
        store.perform(.selectPane(refactor))
        store.perform(.setTerminalVisible(true))
        let paneWindow = store.paneWindow(refactor)
        let log = SessionLog(format: .claude, session: SessionID("00000000-0000-4000-8000-0000000000a1")!)
        let sessionWindow = store.sessionWindow(SessionWindowID(log: log, title: "Earlier"))
        await settle { transcripts.started == 3 }
        #expect(transcripts.open == 3)
        #expect(store.detail.terminal.isPolling)

        store.close()
        await settle { transcripts.open == 0 }
        #expect(transcripts.open == 0)
        #expect(store.detail.conversation.loadTask == nil)
        #expect(!store.detail.terminal.isPolling)
        #expect(paneWindow.isClosed)
        #expect(sessionWindow.isClosed)
    }
}
