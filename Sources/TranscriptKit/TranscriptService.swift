import FabrikaterCore
import Foundation
import HostKit

/// Loads conversations. `HostTranscriptService` is the real one; tests use a fake.
public protocol TranscriptService: Sendable {
    /// The conversation in the last `bytes` bytes of the session's log.
    func claudeTranscript(session: SessionID, bytes: Int) async throws -> Transcript

    /// The conversation in the log's full window, then again each time the log grows, until cancelled. The default
    /// reads once and ends; `HostTranscriptService` follows the log live (`LiveFollow.swift`).
    func followClaudeTranscript(session: SessionID) -> AsyncThrowingStream<Transcript, any Error>
}

/// How much of a log to read.
public enum TranscriptWindow {
    /// A first read that arrives and renders quickly, shown while the full window loads.
    public static let quick = 64 * 1024
    /// The last 512 KB covers most conversations (median log 0.9 MB, docs/architecture.md, "Transcript tail").
    public static let full = 512 * 1024
    /// How far before the log's end a follow starts, so lines written between the read and the follow are not lost.
    /// Lines already read are skipped.
    public static let overlap = 64 * 1024
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
    let runner: any HostCommandRunner
    let reconnectDelays: [Duration]

    /// - Parameter reconnectDelays: waits before following the log again after the follow drops; the last repeats.
    public init(
        runner: any HostCommandRunner,
        reconnectDelays: [Duration] = [.seconds(1), .seconds(2), .seconds(5), .seconds(15), .seconds(30)]
    ) {
        self.runner = runner
        self.reconnectDelays = reconnectDelays.isEmpty ? [.seconds(1)] : reconnectDelays
    }

    public func claudeTranscript(session: SessionID, bytes: Int) async throws -> Transcript {
        Transcript(claudeLog: try await claudeLog(session: session, bytes: bytes), window: bytes)
    }

    /// The last `bytes` bytes of the session's log.
    func claudeLog(session: SessionID, bytes: Int) async throws -> Data {
        do {
            return try await runner.run(.claudeLogTail(session: session, bytes: bytes))
        } catch HostError.exited(HostCommand.notFoundStatus, _) {
            throw TranscriptError.noLog
        }
    }
}
