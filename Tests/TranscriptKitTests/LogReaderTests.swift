import FabrikaterCore
import Foundation
import Testing

@testable import TranscriptKit

/// A followed log is parsed line by line onto what was read before (docs/performance.md); it must read exactly as the
/// whole window read at once.
struct LogReaderTests {
    static let logs: [(SessionLog.Format, String)] = [
        (.claude, "claude.synthetic.jsonl"), (.claude, "claude-changes.synthetic.jsonl"),
        (.claude, "claude-todos.synthetic.jsonl"), (.claude, "claude-facts.synthetic.jsonl"),
        (.claude, "claude-long.synthetic.jsonl"), (.claude, "claude-scale.synthetic.jsonl"),
        (.codex, "codex.synthetic.jsonl"), (.pi, "pi.synthetic.jsonl"), (.opencode, "opencode.synthetic.jsonl"),
    ]

    @Test(arguments: logs)
    func followingReadsAsTheWholeLog(format: SessionLog.Format, name: String) throws {
        let data = try Fixture.data(named: name)
        let lines = String(decoding: data, as: UTF8.self).split(separator: "\n").map(String.init)
        let half = lines.count / 2
        let limit = 16 * 1024 * 1024
        var window = LogWindow(format, read: Data((lines[..<half].joined(separator: "\n") + "\n").utf8), limit: limit)
        for line in lines[half...] {
            _ = window.append(line)
        }
        #expect(window.transcript == Transcript(format, data: window.data, window: limit))
        #expect(window.transcript.entries == Transcript(format, data: data, window: limit).entries)
    }

    @Test func droppingOldLinesReadsAsTheWholeWindow() throws {
        let lines = String(decoding: try Fixture.data(named: "claude-scale.synthetic.jsonl"), as: UTF8.self)
            .split(separator: "\n").map(String.init)
        let limit = 64 * 1024
        var window = LogWindow(.claude, read: Data(), limit: limit)
        for line in lines.prefix(800) {
            _ = window.append(line)
        }
        #expect(window.data.count <= 2 * limit)
        #expect(window.transcript == Transcript(.claude, data: window.data, window: window.data.count))
    }

    /// Guards the live follow against parsing the whole window again for each line. The bound is relative, so a slow
    /// machine slows both sides: before line-by-line reading, 200 lines cost 200 reads of the window.
    @Test func appendingLinesCostsLessThanReadingTheWindowOnce() throws {
        let data = try Fixture.data(named: "claude-scale.synthetic.jsonl")
        let lines = String(decoding: data, as: UTF8.self).split(separator: "\n").map(String.init)
        let tail = lines.suffix(200)
        let read = Data((lines.dropLast(200).joined(separator: "\n") + "\n").utf8).suffix(TranscriptWindow.full)
        let clock = ContinuousClock()
        var window = LogWindow(.claude, read: Data(read), limit: TranscriptWindow.full)
        let once = clock.measure { window = LogWindow(.claude, read: Data(read), limit: TranscriptWindow.full) }
        let appending = clock.measure {
            for line in tail {
                _ = window.append(line)
                _ = window.transcript
            }
        }
        #expect(appending < once, "200 appended lines took \(appending), one read of the window \(once)")
    }
}
