import FabrikaterCore
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
}
