import Foundation

/// Runs `HostCommand`s. `SSHRunner` talks to the host; `ReplayRunner` serves fixtures.
public protocol HostCommandRunner: Sendable {
    /// Runs a one-off command and returns its stdout. `input` is written to stdin, which is then closed.
    func run(_ command: HostCommand, input: Data?) async throws(HostError) -> Data

    /// Starts a long-lived command and streams its stdout line by line, without the newlines.
    /// `input` is written to stdin, which stays open until the stream ends. Cancelling the consumer stops the command.
    func lines(_ command: HostCommand, input: Data?) -> AsyncThrowingStream<String, any Error>
}

extension HostCommandRunner {
    public func run(_ command: HostCommand) async throws(HostError) -> Data {
        try await run(command, input: nil)
    }
}
