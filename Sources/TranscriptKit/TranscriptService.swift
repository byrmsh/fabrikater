import FabrikaterCore
import HostKit

/// Loads conversations. `HostTranscriptService` is the real one; tests use a fake.
public protocol TranscriptService: Sendable {
    func claudeTranscript(session: SessionID) async throws -> Transcript
}

public enum TranscriptError: Error, Equatable, Sendable, CustomStringConvertible {
    case noLog

    public var description: String {
        switch self {
        case .noLog: "No session log was found for this pane"
        }
    }
}

/// Reads the tail of the session log over a `HostCommandRunner` and parses it.
public struct HostTranscriptService: TranscriptService {
    /// The last 512 KB covers most conversations (median log 0.9 MB, docs/architecture.md, "Transcript tail").
    public static let defaultWindow = 512 * 1024

    private let runner: any HostCommandRunner
    private let window: Int

    public init(runner: any HostCommandRunner, window: Int = defaultWindow) {
        self.runner = runner
        self.window = window
    }

    public func claudeTranscript(session: SessionID) async throws -> Transcript {
        do {
            let data = try await runner.run(.claudeLogTail(session: session, bytes: window))
            return Transcript(entries: ClaudeTranscriptParser.parse(data), isClipped: data.count >= window)
        } catch HostError.exited(HostCommand.notFoundStatus, _) {
            throw TranscriptError.noLog
        }
    }
}
