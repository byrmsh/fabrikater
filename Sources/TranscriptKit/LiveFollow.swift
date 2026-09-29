import FabrikaterCore
import Foundation
import HostKit

extension TranscriptService {
    /// No live follow: one read of the window, then the stream ends.
    public func followTranscript(of log: SessionLog, bytes: Int) -> AsyncThrowingStream<FollowUpdate, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    continuation.yield(.transcript(try await transcript(of: log, bytes: bytes)))
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
    /// (docs/architecture.md, "Transcript tail"). A dropped follow says so, then starts over with a fresh read on the
    /// `ReconnectPolicy`'s backoff; only a failure before the first read throws.
    public func followTranscript(of log: SessionLog, bytes: Int) -> AsyncThrowingStream<FollowUpdate, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                let clock = ContinuousClock()
                var backoff = reconnect.backoff()
                var hasRead = false
                while !Task.isCancelled {
                    let started = clock.now
                    do {
                        var window = LogWindow(log.format, read: try await tail(of: log, bytes: bytes), limit: bytes)
                        continuation.yield(.transcript(window.transcript))
                        hasRead = true
                        let follow = runner.lines(
                            .logFollow(log, bytes: TranscriptWindow.overlap), input: nil)
                        // The overlap starts mid-line, and that line was read in full already.
                        for try await line in follow.dropFirst() where window.append(line) {
                            continuation.yield(.transcript(window.transcript))
                        }
                        continuation.yield(.interrupted("The host stopped following the log"))
                    } catch {
                        guard hasRead else { return continuation.finish(throwing: error) }
                        continuation.yield(.interrupted(String(describing: error)))
                    }
                    do {
                        try await reconnect.pause(backoff.delay(afterHolding: clock.now - started))
                    } catch {
                        break
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

/// The part of a log read so far, grown line by line as the log is followed. Each new line is parsed once, onto what
/// was read before; only dropping the oldest lines reads the window again.
struct LogWindow {
    let format: SessionLog.Format
    private(set) var data: Data
    /// True when older history exists before `data`.
    private(set) var isClipped: Bool
    /// Beyond twice this many bytes, the window drops its oldest lines back to this many.
    let limit: Int
    /// Hashes of the lines in the window, so a line the follow delivers again is added once. Log rows carry a unique
    /// id or a timestamp, so equal lines are the same row.
    private var seen: Set<Int>
    /// Everything in `data`, parsed.
    private var reader: any LogReader
    /// The lines in `data`, which always ends with a newline.
    private var lineCount: Int

    init(_ format: SessionLog.Format, read: Data, limit: Int) {
        self.format = format
        // A last line without its newline is still being written; the follow delivers it whole.
        let end = read.lastIndex(of: 0x0A).map { read.index(after: $0) } ?? read.startIndex
        data = Data(read[read.startIndex..<end])
        isClipped = read.count >= limit
        self.limit = limit
        seen = Set(data.split(separator: 0x0A).map { String(decoding: $0, as: UTF8.self).hashValue })
        reader = format.reader(reading: data)
        lineCount = data.count { $0 == 0x0A }
    }

    /// Adds `line`; false when it is blank or already in the window.
    mutating func append(_ line: String) -> Bool {
        guard !line.isEmpty, seen.insert(line.hashValue).inserted else { return false }
        let bytes = Data(line.utf8)
        data.append(bytes)
        data.append(0x0A)
        if data.count > 2 * limit {
            data = Data(data.suffix(limit))
            isClipped = true
            reader = format.reader(reading: data)
            lineCount = data.count { $0 == 0x0A }
        } else {
            lineCount += 1
            reader.read(bytes[...], number: lineCount)
        }
        return true
    }

    var transcript: Transcript {
        var transcript = reader.transcript
        transcript.isClipped = isClipped
        return transcript
    }
}
