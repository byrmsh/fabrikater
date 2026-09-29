import FabrikaterCore
import Foundation

/// What `HerdFeed` publishes: a fresh herd, or why the last read failed.
public enum HerdUpdate: Equatable, Sendable {
    case herd(Herd)
    case failed(String)
}

/// Keeps the herd current: re-reads the snapshot shortly after any Herdr event, and every `pollInterval` in case
/// the event channel silently stalls (docs/architecture.md, "Events"). After a failed read it polls again sooner, on
/// the `ReconnectPolicy`'s backoff.
public actor HerdFeed {
    private let service: any HerdrService
    private let coalesceDelay: Duration
    private let pollInterval: Duration
    private let reconnect: ReconnectPolicy
    private let clock = ContinuousClock()
    private let log = Log(category: "HerdrKit")
    /// Pokes the reader when the next poll is due.
    private var pollTimer: Task<Void, Never>?

    /// - Parameters:
    ///   - coalesceDelay: events arriving within this window after the first one cause a single re-read.
    ///   - reconnect: the waits between reconnects of the event channel, and between reads while they fail.
    public init(
        service: any HerdrService,
        coalesceDelay: Duration = .milliseconds(250),
        pollInterval: Duration = .seconds(20),
        reconnect: ReconnectPolicy = ReconnectPolicy()
    ) {
        self.service = service
        self.coalesceDelay = coalesceDelay
        self.pollInterval = pollInterval
        self.reconnect = reconnect
    }

    /// Starts reading. The first update follows at once; the work stops when the consumer stops iterating.
    public nonisolated func updates() -> AsyncStream<HerdUpdate> {
        AsyncStream { continuation in
            let task = Task { await self.run(continuation) }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Every reason to read (the poll, an event) pokes with the time it happened. One reader serves the pokes in turn,
    /// so reads never overlap, and skips those that came before its last read began, which that read covered.
    private func run(_ output: AsyncStream<HerdUpdate>.Continuation) async {
        let (pokes, poke) = AsyncStream<ContinuousClock.Instant>.makeStream(bufferingPolicy: .bufferingNewest(1))
        poke.yield(clock.now)
        await withDiscardingTaskGroup { group in
            group.addTask { await self.read(on: pokes, into: output, poke: poke) }
            group.addTask { await self.followEvents(poke: poke) }
        }
        pollTimer?.cancel()
        output.finish()
    }

    private func read(
        on pokes: AsyncStream<ContinuousClock.Instant>,
        into output: AsyncStream<HerdUpdate>.Continuation,
        poke: AsyncStream<ContinuousClock.Instant>.Continuation
    ) async {
        var backoff = reconnect.backoff()
        var lastRead: ContinuousClock.Instant?
        for await poked in pokes {
            if let lastRead {
                guard poked >= lastRead else { continue }
                do {
                    try await Task.sleep(for: coalesceDelay)
                } catch {
                    return
                }
            }
            lastRead = clock.now
            let wait: Duration
            if await refresh(output) {
                backoff.reset()
                wait = pollInterval
            } else {
                wait = min(backoff.delay(), pollInterval)
            }
            schedulePoll(after: wait, poke: poke)
        }
    }

    private func schedulePoll(after wait: Duration, poke: AsyncStream<ContinuousClock.Instant>.Continuation) {
        pollTimer?.cancel()
        pollTimer = Task { [reconnect, clock] in
            do {
                try await reconnect.pause(wait)
            } catch {
                return
            }
            poke.yield(clock.now)
        }
    }

    private func followEvents(poke: AsyncStream<ContinuousClock.Instant>.Continuation) async {
        var backoff = reconnect.backoff()
        while !Task.isCancelled {
            let started = clock.now
            do {
                for try await _ in service.events() {
                    poke.yield(clock.now)
                }
                log.info("event channel closed")
            } catch {
                log.error("event channel failed: \(error)")
            }
            do {
                try await reconnect.pause(backoff.delay(afterHolding: clock.now - started))
            } catch {
                return
            }
        }
    }

    /// Reads the snapshot and publishes it, or why it failed; true when it succeeded.
    private func refresh(_ output: AsyncStream<HerdUpdate>.Continuation) async -> Bool {
        do {
            output.yield(.herd(try await service.snapshot()))
            return true
        } catch {
            log.error("snapshot failed: \(error)")
            output.yield(.failed(String(describing: error)))
            return false
        }
    }
}
