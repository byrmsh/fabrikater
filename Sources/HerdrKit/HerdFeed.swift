import FabrikaterCore
import Foundation

/// What `HerdFeed` publishes: a fresh herd, or why the last read failed.
public enum HerdUpdate: Equatable, Sendable {
    case herd(Herd)
    case failed(String)
}

/// Keeps the herd current: re-reads the snapshot shortly after any Herdr event, and every `pollInterval` in case
/// the event channel silently stalls (docs/architecture.md, "Events").
public actor HerdFeed {
    private let service: any HerdrService
    private let coalesceDelay: Duration
    private let pollInterval: Duration
    private let reconnectDelays: [Duration]
    private let log = Log(category: "HerdrKit")
    private var refreshScheduled = false

    /// - Parameters:
    ///   - coalesceDelay: events arriving within this window after the first one cause a single re-read.
    ///   - reconnectDelays: waits between reconnects of the event channel; the last one repeats.
    public init(
        service: any HerdrService,
        coalesceDelay: Duration = .milliseconds(250),
        pollInterval: Duration = .seconds(20),
        reconnectDelays: [Duration] = [.seconds(1), .seconds(2), .seconds(5), .seconds(15), .seconds(30)]
    ) {
        self.service = service
        self.coalesceDelay = coalesceDelay
        self.pollInterval = pollInterval
        self.reconnectDelays = reconnectDelays.isEmpty ? [.seconds(1)] : reconnectDelays
    }

    /// Starts reading. The first update follows at once; the work stops when the consumer stops iterating.
    public nonisolated func updates() -> AsyncStream<HerdUpdate> {
        AsyncStream { continuation in
            let task = Task { await self.run(continuation) }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func run(_ output: AsyncStream<HerdUpdate>.Continuation) async {
        await withDiscardingTaskGroup { group in
            group.addTask { await self.poll(output) }
            group.addTask { await self.followEvents(output) }
        }
        output.finish()
    }

    private func poll(_ output: AsyncStream<HerdUpdate>.Continuation) async {
        while !Task.isCancelled {
            await refresh(output)
            do {
                try await Task.sleep(for: pollInterval)
            } catch {
                return
            }
        }
    }

    private func followEvents(_ output: AsyncStream<HerdUpdate>.Continuation) async {
        var failures = 0
        while !Task.isCancelled {
            do {
                for try await _ in service.events() {
                    failures = 0
                    scheduleRefresh(output)
                }
                log.info("event channel closed")
            } catch {
                log.error("event channel failed: \(error)")
            }
            let delay = reconnectDelays[min(failures, reconnectDelays.count - 1)]
            failures += 1
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }
        }
    }

    private func scheduleRefresh(_ output: AsyncStream<HerdUpdate>.Continuation) {
        guard !refreshScheduled else { return }
        refreshScheduled = true
        Task {
            try? await Task.sleep(for: coalesceDelay)
            await self.runScheduledRefresh(output)
        }
    }

    private func runScheduledRefresh(_ output: AsyncStream<HerdUpdate>.Continuation) async {
        refreshScheduled = false
        await refresh(output)
    }

    private func refresh(_ output: AsyncStream<HerdUpdate>.Continuation) async {
        do {
            output.yield(.herd(try await service.snapshot()))
        } catch {
            log.error("snapshot failed: \(error)")
            output.yield(.failed(String(describing: error)))
        }
    }
}
