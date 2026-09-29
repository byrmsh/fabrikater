import Testing

@testable import FabrikaterCore

struct ReconnectTests {
    @Test func eachFailureInARowWaitsLongerAndTheLastWaitRepeats() {
        var backoff = Backoff(delays: [.seconds(1), .seconds(5)])
        #expect(backoff.delay() == .seconds(1))
        #expect(backoff.delay() == .seconds(5))
        #expect(backoff.delay() == .seconds(5))
    }

    @Test func aConnectionThatHeldStartsTheCountOver() {
        var backoff = Backoff(delays: [.seconds(1), .seconds(5)], steadyAfter: .seconds(30))
        _ = backoff.delay()
        _ = backoff.delay(afterHolding: .seconds(29))
        #expect(backoff.delay(afterHolding: .seconds(2)) == .seconds(5))
        #expect(backoff.delay(afterHolding: .seconds(30)) == .seconds(1))
    }

    @Test func aSuccessStartsTheCountOver() {
        var backoff = Backoff(delays: [.seconds(1), .seconds(5)])
        _ = backoff.delay()
        backoff.reset()
        #expect(backoff.delay() == .seconds(1))
    }

    @Test func noDelaysMeansOneSecond() {
        var backoff = ReconnectPolicy(delays: []).backoff()
        #expect(backoff.delay() == .seconds(1))
    }

    @Test func retryNowEndsAPauseEarly() async throws {
        let policy = ReconnectPolicy()
        let clock = ContinuousClock()
        let started = clock.now
        // Retried until the pause ends, since the pause may not have begun waiting at the first call.
        let waker = Task {
            while !Task.isCancelled {
                policy.retryNow()
                try await Task.sleep(for: .milliseconds(5))
            }
        }
        defer { waker.cancel() }
        try await policy.pause(.seconds(3600))
        #expect(clock.now - started < .seconds(60))
    }

    @Test func cancellingAPauseThrows() async {
        let policy = ReconnectPolicy()
        let pause = Task { try await policy.pause(.seconds(3600)) }
        pause.cancel()
        await #expect(throws: CancellationError.self) { try await pause.value }
    }

    @Test func aPauseWithoutRetryLastsItsDuration() async throws {
        let clock = ContinuousClock()
        let started = clock.now
        try await ReconnectPolicy().pause(.milliseconds(20))
        #expect(clock.now - started >= .milliseconds(20))
    }
}
