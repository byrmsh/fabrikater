import FabrikaterCore
import HostKit
import Synchronization
import Testing

@testable import HerdrKit

struct HerdFeedTests {
    /// A service whose events the test pushes by hand, counting snapshot reads.
    private final class FakeService: HerdrService {
        let stream: AsyncThrowingStream<Void, any Error>
        let eventSink: AsyncThrowingStream<Void, any Error>.Continuation
        private let reads = Counter()
        private let failing: Bool

        init(failing: Bool = false) {
            (stream, eventSink) = AsyncThrowingStream.makeStream()
            self.failing = failing
        }

        var snapshotCount: Int { get async { await reads.value } }

        func snapshot() async throws -> Herd {
            await reads.increment()
            if failing { throw HerdrError("unreachable") }
            return Herd(workspaces: [.init(id: "w1", label: "read \(await reads.value)", number: 1)])
        }

        func events() -> AsyncThrowingStream<Void, any Error> { stream }
    }

    private actor Counter {
        var value = 0
        func increment() { value += 1 }
    }

    @Test func burstOfEventsCausesOneRefresh() async throws {
        let service = FakeService()
        let feed = HerdFeed(service: service, coalesceDelay: .milliseconds(50), pollInterval: .seconds(60))
        var updates = feed.updates().makeAsyncIterator()

        #expect(await updates.next() != nil)  // the first poll
        for _ in 0..<5 { service.eventSink.yield() }
        let second = await updates.next()

        #expect(second == .herd(Herd(workspaces: [.init(id: "w1", label: "read 2", number: 1)])))
        try await Task.sleep(for: .milliseconds(200))
        #expect(await service.snapshotCount == 2)
    }

    @Test func aFailedReadIsReported() async {
        let feed = HerdFeed(service: FakeService(failing: true), pollInterval: .seconds(60))
        var updates = feed.updates().makeAsyncIterator()
        #expect(await updates.next() == .failed("unreachable"))
    }

    @Test func pollsAgainAfterTheInterval() async {
        let service = FakeService()
        let feed = HerdFeed(service: service, pollInterval: .milliseconds(50))
        var updates = feed.updates().makeAsyncIterator()
        _ = await updates.next()
        _ = await updates.next()
        #expect(await service.snapshotCount >= 2)
    }

    /// A host that is down for the first `downReads` snapshot reads and whose event channel drops after `events`
    /// events each time, counting reads, the most running at once, and channel openings.
    private final class FlakyService: HerdrService {
        private struct State {
            var reads = 0
            var running = 0
            var mostRunning = 0
            var channels = 0
        }

        private let state = Mutex(State())
        private let downReads: Int
        private let readTime: Duration
        private let eventsPerChannel: Int

        init(downReads: Int = 0, readTime: Duration = .zero, events: Int = 0) {
            self.downReads = downReads
            self.readTime = readTime
            self.eventsPerChannel = events
        }

        var reads: Int { state.withLock { $0.reads } }
        var mostRunning: Int { state.withLock { $0.mostRunning } }
        var channels: Int { state.withLock { $0.channels } }

        func snapshot() async throws -> Herd {
            let read = state.withLock { state in
                state.reads += 1
                state.running += 1
                state.mostRunning = max(state.mostRunning, state.running)
                return state.reads
            }
            try? await Task.sleep(for: readTime)
            state.withLock { $0.running -= 1 }
            if read <= downReads { throw HostError.exited(status: 255, stderr: "connection lost") }
            return Herd(workspaces: [.init(id: "w1", label: "read \(read)", number: 1)])
        }

        func events() -> AsyncThrowingStream<Void, any Error> {
            state.withLock { $0.channels += 1 }
            return AsyncThrowingStream { [eventsPerChannel] channel in
                for _ in 0..<eventsPerChannel { channel.yield() }
                channel.finish(throwing: HostError.exited(status: 255, stderr: "connection lost"))
            }
        }
    }

    @Test func whileTheHostIsDownReadsRetryOnTheBackoffAndRecover() async {
        let service = FlakyService(downReads: 2)
        let feed = HerdFeed(
            service: service, coalesceDelay: .zero, pollInterval: .seconds(3600),
            reconnect: ReconnectPolicy(delays: [.milliseconds(10)]))
        var updates = feed.updates().makeAsyncIterator()

        #expect(await updates.next() == .failed("ssh failed: connection lost"))
        #expect(await updates.next() == .failed("ssh failed: connection lost"))
        #expect(await updates.next() == .herd(Herd(workspaces: [.init(id: "w1", label: "read 3", number: 1)])))
    }

    @Test func aDroppedEventChannelReconnectsOnTheBackoff() async throws {
        let service = FlakyService()
        let feed = HerdFeed(
            service: service, pollInterval: .seconds(3600), reconnect: ReconnectPolicy(delays: [.milliseconds(10)]))
        let reading = Task { for await _ in feed.updates() {} }
        defer { reading.cancel() }
        for _ in 0..<200 where service.channels < 3 {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(service.channels >= 3)
    }

    @Test func readsNeverOverlapHoweverManyPokesArrive() async throws {
        let service = FlakyService(readTime: .milliseconds(30), events: 1)
        let feed = HerdFeed(
            service: service, coalesceDelay: .zero, pollInterval: .milliseconds(5),
            reconnect: ReconnectPolicy(delays: [.milliseconds(1)]))
        var updates = feed.updates().makeAsyncIterator()
        for _ in 0..<5 { _ = await updates.next() }
        #expect(service.channels > 5)
        #expect(service.mostRunning == 1)
    }

    @Test func retryNowReadsAtOnceInsteadOfWaitingForThePoll() async throws {
        let service = FlakyService(downReads: 1)
        let reconnect = ReconnectPolicy(delays: [.seconds(3600)])
        let feed = HerdFeed(service: service, coalesceDelay: .zero, pollInterval: .seconds(3600), reconnect: reconnect)
        var updates = feed.updates().makeAsyncIterator()
        #expect(await updates.next() == .failed("ssh failed: connection lost"))

        let waker = Task {
            while !Task.isCancelled {
                reconnect.retryNow()
                try await Task.sleep(for: .milliseconds(10))
            }
        }
        defer { waker.cancel() }
        #expect(await updates.next() == .herd(Herd(workspaces: [.init(id: "w1", label: "read 2", number: 1)])))
    }
}
