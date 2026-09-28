import FabrikaterCore
import HerdrKit
import Synchronization
import Testing
import TranscriptKit

@testable import AppModel

@MainActor
struct BackfillTests {
    /// A log of `size` bytes: a window shows one entry per 64 KB it reads, and is clipped when it reads less than all.
    private final class SizedLog: TranscriptService {
        let size: Int
        let windows = Mutex<[Int]>([])

        init(size: Int) {
            self.size = size
        }

        func claudeTranscript(session: SessionID, bytes: Int) async throws -> Transcript {
            windows.withLock { $0.append(bytes) }
            let read = min(bytes, size)
            return Transcript(
                entries: (0..<(read / 65536)).map { TranscriptEntry(id: "e\($0)", role: .assistant, parts: []) },
                isClipped: bytes < size)
        }
    }

    private let refactor = PaneID("w1:p1")!
    private let scratch = PaneID("w2:p1")!

    private func makeStore(log: SizedLog) throws -> AppStore {
        let store = AppStore(herdUpdates: AsyncStream { $0.finish() }, transcripts: log, control: FakeControl())
        store.apply(.herd(try Herd(snapshotReply: Fixture.data(named: "snapshot.synthetic.json"))))
        return store
    }

    private func show(_ pane: PaneID, in store: AppStore) async {
        store.perform(.selectPane(pane))
        await store.conversation.loadTask?.value
    }

    @Test func earlierWindowsDoubleUpToTheLargest() {
        #expect(TranscriptWindow.earlier(than: TranscriptWindow.full) == 2 * TranscriptWindow.full)
        #expect(TranscriptWindow.earlier(than: 6 * 1024 * 1024) == TranscriptWindow.largest)
        #expect(TranscriptWindow.earlier(than: TranscriptWindow.largest) == nil)
    }

    @Test func aWholeLogOffersNothingEarlier() async throws {
        let store = try makeStore(log: SizedLog(size: 100_000))
        await show(refactor, in: store)
        #expect(!store.isEnabled(.loadEarlier))
        #expect(store.conversation.earlierNote == nil)
    }

    @Test func loadEarlierReadsTwiceAsMuchAndKeepsGoingUntilTheStart() async throws {
        let log = SizedLog(size: 1_500_000)
        let store = try makeStore(log: log)
        await show(refactor, in: store)
        #expect(store.conversation.transcript.entries.count == 8)
        #expect(store.isEnabled(.loadEarlier))
        #expect(store.conversation.earlierNote == nil)

        store.perform(.loadEarlier)
        #expect(store.conversation.earlierNote == "Loading earlier messages…")
        #expect(!store.isEnabled(.loadEarlier))
        await store.conversation.loadTask?.value
        #expect(store.conversation.window == 2 * TranscriptWindow.full)
        #expect(store.conversation.transcript.entries.count == 16)

        store.perform(.loadEarlier)
        await store.conversation.loadTask?.value
        #expect(!store.conversation.transcript.isClipped)
        #expect(!store.isEnabled(.loadEarlier))
        #expect(log.windows.withLock { $0 }.suffix(2) == [2 * TranscriptWindow.full, 4 * TranscriptWindow.full])
    }

    @Test func aReloadKeepsTheLargerWindowAndAnotherPaneStartsOver() async throws {
        let log = SizedLog(size: 1_500_000)
        let store = try makeStore(log: log)
        await show(refactor, in: store)
        store.perform(.loadEarlier)
        await store.conversation.loadTask?.value

        store.perform(.reloadConversation)
        await store.conversation.loadTask?.value
        #expect(log.windows.withLock { $0 }.last == 2 * TranscriptWindow.full)

        await show(scratch, in: store)
        #expect(store.conversation.window == TranscriptWindow.full)
        #expect(log.windows.withLock { $0 }.last == TranscriptWindow.full)
    }

    @Test func aLogPastTheLargestWindowSaysSo() async throws {
        let store = try makeStore(log: SizedLog(size: 50_000_000))
        await show(refactor, in: store)
        for _ in 0..<4 {
            store.perform(.loadEarlier)
            await store.conversation.loadTask?.value
        }
        #expect(store.conversation.window == TranscriptWindow.largest)
        #expect(store.conversation.transcript.isClipped)
        #expect(store.conversation.earlierNote == "Earlier messages are too far back to load.")
    }
}
