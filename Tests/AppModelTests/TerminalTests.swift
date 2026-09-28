import FabrikaterCore
import Foundation
import HerdrKit
import Testing
import TranscriptKit

@testable import AppModel

@MainActor
struct TerminalTests {
    /// Serves one screen per read, in order, repeating the last, and records which panes were read.
    private final class FakeTerminals: TerminalReader, @unchecked Sendable {
        var screens: [String]
        var error: (any Error)?
        private(set) var reads: [PaneID] = []

        init(_ screens: String...) {
            self.screens = screens
        }

        func recent(of pane: PaneID, lines: Int) async throws -> String {
            reads.append(pane)
            if let error { throw error }
            return screens[min(reads.count - 1, screens.count - 1)]
        }
    }

    /// A fake clock for the pause between reads: each pause waits until the test calls `tick()`.
    private final class Ticker: @unchecked Sendable {
        private var waiters: [CheckedContinuation<Void, Never>] = []
        private let lock = NSLock()

        var waiting: Int { lock.withLock { waiters.count } }

        @Sendable func pause(_ duration: Duration) async throws {
            await withCheckedContinuation { continuation in
                lock.withLock { waiters.append(continuation) }
            }
        }

        func tick() {
            let released = lock.withLock {
                defer { waiters.removeAll() }
                return waiters
            }
            for waiter in released { waiter.resume() }
        }
    }

    private struct EmptyTranscripts: TranscriptService {
        func claudeTranscript(session: SessionID, bytes: Int) async throws -> Transcript { Transcript() }
    }

    private let refactor = PaneID("w1:p1")!
    private let scratch = PaneID("w2:p1")!
    private let ticker = Ticker()

    private func settle(until condition: () -> Bool) async {
        for _ in 0..<1000 where !condition() {
            await Task.yield()
        }
    }

    private func makeTerminal(_ reader: FakeTerminals) -> TerminalStore {
        TerminalStore(reader: reader, pause: ticker.pause)
    }

    @Test func readsOnlyWhileVisible() async {
        let reader = FakeTerminals("one")
        let terminal = makeTerminal(reader)
        terminal.show(refactor)
        #expect(!terminal.isPolling)
        terminal.setVisible(true)
        #expect(terminal.isPolling)
        await settle { ticker.waiting == 1 }
        #expect(reader.reads == [refactor])
        #expect(terminal.screen == TerminalScreen(ansi: "one"))
    }

    @Test func pollsEveryIntervalUntilHidden() async {
        let reader = FakeTerminals("one", "two")
        let terminal = makeTerminal(reader)
        terminal.show(refactor)
        terminal.setVisible(true)
        await settle { ticker.waiting == 1 }
        ticker.tick()
        await settle { reader.reads.count == 2 && ticker.waiting == 1 }
        #expect(terminal.screen == TerminalScreen(ansi: "two"))
        terminal.setVisible(false)
        #expect(!terminal.isPolling)
        ticker.tick()
        for _ in 0..<50 { await Task.yield() }
        #expect(reader.reads.count == 2)
        #expect(ticker.waiting == 0)
    }

    @Test func anotherPaneDropsTheScreenAndReadsTheNewPane() async {
        let reader = FakeTerminals("one")
        let terminal = makeTerminal(reader)
        terminal.show(refactor)
        terminal.setVisible(true)
        await settle { terminal.screen != nil }
        terminal.show(scratch)
        #expect(terminal.screen == nil)
        #expect(terminal.content == .reading("Reading the terminal…"))
        await settle { reader.reads.count == 2 }
        #expect(reader.reads == [refactor, scratch])
    }

    @Test func aNewWidthForTheSamePaneKeepsTheScreenAndTheReads() async {
        let reader = FakeTerminals("one")
        let terminal = makeTerminal(reader)
        terminal.show(refactor, columns: 120)
        terminal.setVisible(true)
        await settle { terminal.screen != nil }
        terminal.show(refactor, columns: 182)
        #expect(terminal.columns == 182)
        #expect(terminal.screen == TerminalScreen(ansi: "one"))
        #expect(reader.reads == [refactor])
        terminal.show(scratch)
        #expect(terminal.columns == nil)
    }

    @Test func noPaneStopsReading() async {
        let reader = FakeTerminals("one")
        let terminal = makeTerminal(reader)
        terminal.show(refactor)
        terminal.setVisible(true)
        terminal.show(nil)
        #expect(!terminal.isPolling)
        #expect(terminal.content == .gone("This pane is no longer in Herdr."))
    }

    @Test func aFailedReadKeepsTheLastScreenAndSaysItIsStale() async {
        let reader = FakeTerminals("one")
        let terminal = makeTerminal(reader)
        terminal.show(refactor)
        terminal.setVisible(true)
        await settle { ticker.waiting == 1 }
        reader.error = HerdrError("timed out")
        ticker.tick()
        await settle { terminal.failure != nil }
        #expect(terminal.screen == TerminalScreen(ansi: "one"))
        #expect(terminal.failure?.contains("timed out") == true)
        #expect(terminal.content == .screen(TerminalScreen(ansi: "one"), stale: terminal.failure))
        #expect(terminal.isPolling)
        reader.error = nil
        await settle { ticker.waiting == 1 }
        ticker.tick()
        await settle { terminal.failure == nil }
        #expect(terminal.screen == TerminalScreen(ansi: "one"))
    }

    @Test func aFirstReadThatFailsSaysTheTerminalIsUnavailable() async {
        let reader = FakeTerminals("one")
        reader.error = HerdrError("timed out")
        let terminal = makeTerminal(reader)
        terminal.show(refactor)
        terminal.setVisible(true)
        await settle { terminal.failure != nil }
        guard case .unavailable(let title, let reason) = terminal.content else {
            Issue.record("expected the terminal to be unavailable, got \(terminal.content)")
            return
        }
        #expect(title == "Terminal Unavailable")
        #expect(reason.contains("timed out"))
    }

    @Test func screenBytesResetTheTerminalAndEndLinesWithCarriageReturns() {
        let bytes = TerminalScreen(ansi: "a\nb\r\nc").bytes
        #expect(String(decoding: bytes, as: UTF8.self) == "\u{1B}c\u{1B}[?7l\u{1B}[?25la\r\nb\r\nc")
    }

    @Test func theFeedHoldsNewScreensWhileTheUserReadsAbove() {
        var feed = TerminalFeed()
        #expect(feed.resized() == nil)
        let one = TerminalScreen(ansi: "one")
        let two = TerminalScreen(ansi: "two")
        let three = TerminalScreen(ansi: "three")
        #expect(feed.receive(nil) == nil)
        #expect(feed.receive(one) == one.bytes)
        #expect(feed.receive(one) == nil)
        #expect(feed.scrolled(toBottom: false) == nil)
        #expect(feed.receive(two) == nil)
        #expect(feed.receive(three) == nil)
        #expect(feed.scrolled(toBottom: true) == three.bytes)
        #expect(feed.scrolled(toBottom: true) == nil)
        #expect(feed.receive(three) == nil)
        #expect(feed.resized() == three.bytes)
    }

    @Test func theFeedDropsAHeldScreenWhenTheShownOneComesBack() {
        var feed = TerminalFeed()
        let one = TerminalScreen(ansi: "one")
        _ = feed.receive(one)
        _ = feed.scrolled(toBottom: false)
        _ = feed.receive(TerminalScreen(ansi: "two"))
        #expect(feed.receive(one) == nil)
        #expect(feed.scrolled(toBottom: true) == nil)
    }

    @Test func showTerminalSwitchesTheMainWindowsDetail() throws {
        let store = AppStore(
            herdUpdates: AsyncStream { $0.finish() }, transcripts: EmptyTranscripts(), control: FakeControl(),
            terminals: FakeTerminals("one"))
        #expect(!store.isEnabled(.toggleTerminal))
        store.apply(.herd(try Herd(snapshotReply: Fixture.data(named: "snapshot.synthetic.json"))))
        store.perform(.selectPane(scratch))
        #expect(store.layout.detail == .conversation)
        #expect(store.isChecked(.toggleTerminal) == false)
        store.perform(.toggleTerminal)
        #expect(store.layout.detail == .terminal)
        #expect(store.isChecked(.toggleTerminal) == true)
        #expect(store.terminal.paneID == scratch)
        store.perform(.showPanel(.conversation))
        #expect(store.layout.detail == .conversation)
        #expect(Keymap.chord(for: .toggleTerminal) == KeyChord(.character("t")))
    }

    @Test func theMainWindowsTerminalFollowsTheSelectionAndReadsOnlyOnScreen() async throws {
        let reader = FakeTerminals("one")
        let store = AppStore(
            herdUpdates: AsyncStream { $0.finish() }, transcripts: EmptyTranscripts(), control: FakeControl(),
            terminals: reader)
        store.apply(.herd(try Herd(snapshotReply: Fixture.data(named: "snapshot.synthetic.json"))))
        store.perform(.selectPane(scratch))
        store.perform(.toggleTerminal)
        #expect(!store.terminal.isPolling)
        store.perform(.setTerminalVisible(true))
        await settle { !reader.reads.isEmpty }
        #expect(reader.reads == [scratch])
        store.perform(.selectPane(refactor))
        #expect(store.terminal.paneID == refactor)
        store.perform(.setTerminalVisible(false))
        #expect(!store.terminal.isPolling)
    }

    @Test func aPaneWindowHasItsOwnLayoutAndTerminal() throws {
        let store = AppStore(
            herdUpdates: AsyncStream { $0.finish() }, transcripts: EmptyTranscripts(), control: FakeControl(),
            terminals: FakeTerminals("one"))
        store.apply(.herd(try Herd(snapshotReply: Fixture.data(named: "snapshot.synthetic.json"))))
        store.perform(.selectPane(scratch))
        let window = store.paneWindow(refactor)
        let target = MenuTarget(app: store, window: window)
        target.perform(.toggleTerminal)
        #expect(window.layout.detail == .terminal)
        #expect(target.isChecked(.toggleTerminal) == true)
        #expect(store.layout.detail == .conversation)
        #expect(window.terminal.paneID == refactor)
        #expect(store.terminal.paneID == scratch)
    }

    @Test func aPaneWindowStopsReadingOnceItsPaneLeavesHerdr() async throws {
        let reader = FakeTerminals("one")
        let store = AppStore(
            herdUpdates: AsyncStream { $0.finish() }, transcripts: EmptyTranscripts(), control: FakeControl(),
            terminals: reader)
        store.apply(.herd(try Herd(snapshotReply: Fixture.data(named: "snapshot.synthetic.json"))))
        let window = store.paneWindow(refactor)
        window.perform(.setTerminalVisible(true))
        #expect(window.terminal.isPolling)
        store.apply(.herd(Herd()))
        #expect(!window.terminal.isPolling)
        #expect(window.terminal.content == .gone("This pane is no longer in Herdr."))
    }
}
