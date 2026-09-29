import Synchronization

/// The one rule every long-lived host feed recovers by (the event channel, the snapshot poll, a followed log, the
/// terminal view): wait longer after each failure in a row, count again from the start once a connection held, and
/// stop waiting when `retryNow()` says the network is probably back (the Mac woke from sleep).
public final class ReconnectPolicy: Sendable {
    public static let standardDelays: [Duration] = [
        .seconds(1), .seconds(2), .seconds(5), .seconds(15), .seconds(30),
    ]

    /// Waits after the first, second, … failure in a row; the last one repeats.
    public let delays: [Duration]
    /// A connection that held this long counts as recovered: its failure waits the first delay again.
    public let steadyAfter: Duration

    private struct Waiters {
        var next = 0
        var waiting: [Int: CheckedContinuation<Void, Never>] = [:]
    }

    private let waiters = Mutex(Waiters())

    public init(delays: [Duration] = standardDelays, steadyAfter: Duration = .seconds(30)) {
        self.delays = delays.isEmpty ? [.seconds(1)] : delays
        self.steadyAfter = steadyAfter
    }

    /// A fresh failure count for one feed.
    public func backoff() -> Backoff {
        Backoff(delays: delays, steadyAfter: steadyAfter)
    }

    /// Sleeps for `duration`, or until `retryNow()`. Throws `CancellationError` when the calling task is cancelled.
    public func pause(_ duration: Duration) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await Task.sleep(for: duration) }
            group.addTask { await self.nextRetry() }
            defer { group.cancelAll() }
            _ = try await group.next()
        }
        try Task.checkCancellation()
    }

    /// Ends every `pause` now, so each feed tries again at once.
    public func retryNow() {
        let released = waiters.withLock { waiters in
            defer { waiters.waiting.removeAll() }
            return Array(waiters.waiting.values)
        }
        for waiter in released { waiter.resume() }
    }

    /// Returns at the next `retryNow()`, or when the task is cancelled.
    private func nextRetry() async {
        let id = waiters.withLock { waiters in
            defer { waiters.next += 1 }
            return waiters.next
        }
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                // Checked under the lock the cancellation handler takes, so a cancellation is never missed.
                let isCancelled = waiters.withLock { waiters in
                    if Task.isCancelled { return true }
                    waiters.waiting[id] = continuation
                    return false
                }
                if isCancelled { continuation.resume() }
            }
        } onCancel: {
            waiters.withLock { $0.waiting.removeValue(forKey: id) }?.resume()
        }
    }
}

/// One feed's failures in a row, under a `ReconnectPolicy`.
public struct Backoff: Equatable, Sendable {
    public let delays: [Duration]
    public let steadyAfter: Duration
    public private(set) var failures = 0

    public init(delays: [Duration] = ReconnectPolicy.standardDelays, steadyAfter: Duration = .seconds(30)) {
        self.delays = delays.isEmpty ? [.seconds(1)] : delays
        self.steadyAfter = steadyAfter
    }

    /// The wait before trying again after an attempt that failed having held for `held`.
    public mutating func delay(afterHolding held: Duration = .zero) -> Duration {
        if held >= steadyAfter { failures = 0 }
        defer { failures += 1 }
        return delays[min(failures, delays.count - 1)]
    }

    /// An attempt succeeded: the next failure waits the first delay.
    public mutating func reset() {
        failures = 0
    }
}
