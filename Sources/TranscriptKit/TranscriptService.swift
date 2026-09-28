import FabrikaterCore
import Foundation
import HostKit

/// Loads conversations. `HostTranscriptService` is the real one; tests use a fake.
public protocol TranscriptService: Sendable {
    /// The conversation in the last `bytes` bytes of the session's log.
    func transcript(of log: SessionLog, bytes: Int) async throws -> Transcript

    /// The conversation in the log's last `bytes` bytes, then again each time the log grows, until cancelled. The
    /// default reads once and ends; `HostTranscriptService` follows the log live (`LiveFollow.swift`).
    func followTranscript(of log: SessionLog, bytes: Int) -> AsyncThrowingStream<Transcript, any Error>
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
    /// The most a conversation reads when the user loads earlier messages; past the 95th percentile log (3.9 MB).
    public static let largest = 8 * 1024 * 1024

    /// The window that shows messages before those in `bytes`: twice as much, or nil once `largest` is read.
    public static func earlier(than bytes: Int) -> Int? {
        bytes < largest ? min(bytes * 2, largest) : nil
    }
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

    public func transcript(of log: SessionLog, bytes: Int) async throws -> Transcript {
        Transcript(log.format, data: try await tail(of: log, bytes: bytes), window: bytes)
    }

    /// The last `bytes` bytes of the session's log.
    func tail(of log: SessionLog, bytes: Int) async throws -> Data {
        do {
            return try await runner.run(.logTail(log, bytes: bytes))
        } catch HostError.exited(HostCommand.notFoundStatus, _) {
            throw TranscriptError.noLog
        }
    }
}
