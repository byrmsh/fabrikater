import FabrikaterCore
import HostKit

/// Loads conversations. `HostTranscriptService` is the real one; tests use a fake.
public protocol TranscriptService: Sendable {
    /// The conversation in the last `bytes` bytes of the session's log.
    func claudeTranscript(session: SessionID, bytes: Int) async throws -> Transcript
}

/// How much of a log to read.
public enum TranscriptWindow {
    /// A first read that arrives and renders quickly, shown while the full window loads.
    public static let quick = 64 * 1024
    /// The last 512 KB covers most conversations (median log 0.9 MB, docs/architecture.md, "Transcript tail").
    public static let full = 512 * 1024
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
    private let runner: any HostCommandRunner

    public init(runner: any HostCommandRunner) {
        self.runner = runner
    }

    public func claudeTranscript(session: SessionID, bytes: Int) async throws -> Transcript {
        do {
            let data = try await runner.run(.claudeLogTail(session: session, bytes: bytes))
            return Transcript(
                entries: ClaudeTranscriptParser.parse(data),
                isClipped: data.count >= bytes,
                facts: SessionFacts.claude(data)
            )
        } catch HostError.exited(HostCommand.notFoundStatus, _) {
            throw TranscriptError.noLog
        }
    }
}
