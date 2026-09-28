/// Waits for a while; tests pass one that returns at once, or one they release by hand.
public typealias Pause = @Sendable (Duration) async throws -> Void

/// Waits for real: the stores' default `Pause`.
public let taskSleep: Pause = { try await Task.sleep(for: $0) }

/// How long the app looks for a pane's screen to show what it just sent (typed text in the input box, an answered
/// prompt gone): Collie's 8 reads, 350 ms apart.
enum ScreenWait {
    static let reads = 8
    static let interval = Duration.milliseconds(350)
}
