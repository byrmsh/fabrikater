import FabrikaterCore
import Foundation
import HostKit

extension TranscriptService {
    /// No live follow: one read of the window, then the stream ends.
    public func followClaudeTranscript(session: SessionID, bytes: Int) -> AsyncThrowingStream<Transcript, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    continuation.yield(try await claudeTranscript(session: session, bytes: bytes))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

extension HostTranscriptService {
    /// Reads the last `bytes` bytes, then follows the log with `tail -F` and yields the conversation again for each new line
    /// (docs/architecture.md, "Transcript tail"). A dropped follow starts over with a fresh read after a backoff; only a
    /// failure before the first read throws.
    public func followClaudeTranscript(session: SessionID, bytes: Int) -> AsyncThrowingStream<Transcript, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var failures = 0
                var hasRead = false
                while !Task.isCancelled {
                    do {
                        var window = ClaudeLogWindow(
                            try await claudeLog(session: session, bytes: bytes), limit: bytes)
                        continuation.yield(window.transcript)
                        hasRead = true
                        failures = 0
                        let follow = runner.lines(
                            .claudeLogFollow(session: session, bytes: TranscriptWindow.overlap), input: nil)
                        // The overlap starts mid-line, and that line was read in full already.
                        for try await line in follow.dropFirst() where window.append(line) {
                            continuation.yield(window.transcript)
                        }
                    } catch {
                        guard hasRead else { return continuation.finish(throwing: error) }
                    }
                    let delay = reconnectDelays[min(failures, reconnectDelays.count - 1)]
                    failures += 1
                    try? await Task.sleep(for: delay)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

/// The part of a Claude log read so far, grown line by line as the log is followed.
struct ClaudeLogWindow {
    private(set) var data: Data
    /// True when older history exists before `data`.
    private(set) var isClipped: Bool
    /// Beyond twice this many bytes, the window drops its oldest lines back to this many.
    let limit: Int
    /// Hashes of the lines in the window, so a line the follow delivers again is added once. Log rows carry a unique
    /// `uuid`, so equal lines are the same row.
    private var seen: Set<Int>

    init(_ read: Data, limit: Int) {
        // A last line without its newline is still being written; the follow delivers it whole.
        let end = read.lastIndex(of: 0x0A).map { read.index(after: $0) } ?? read.startIndex
        data = Data(read[read.startIndex..<end])
        isClipped = read.count >= limit
        self.limit = limit
        seen = Set(data.split(separator: 0x0A).map { String(decoding: $0, as: UTF8.self).hashValue })
    }

    /// Adds `line`; false when it is blank or already in the window.
    mutating func append(_ line: String) -> Bool {
        guard !line.isEmpty, seen.insert(line.hashValue).inserted else { return false }
        data.append(contentsOf: line.utf8)
        data.append(0x0A)
        if data.count > 2 * limit {
            data = Data(data.suffix(limit))
            isClipped = true
        }
        return true
    }

    var transcript: Transcript {
        var transcript = Transcript(claudeLog: data, window: limit)
        transcript.isClipped = isClipped
        return transcript
    }
}
