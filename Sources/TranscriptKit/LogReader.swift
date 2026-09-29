import FabrikaterCore
import Foundation

/// Reads a session log one line at a time, so a followed log parses only the lines it adds instead of the whole window
/// again (docs/performance.md). Each format's parser is one; `Transcript(_:data:window:)` feeds it a whole read.
protocol LogReader {
    init()
    /// Reads the next line of the log; `number` counts from 1 at the start of the read, blank lines included.
    mutating func read(_ line: Data.SubSequence, number: Int)
    /// Everything read so far, not yet marked clipped.
    var transcript: Transcript { get }
}

extension LogReader {
    /// A reader that has read every line of `data`.
    static func reading(_ data: Data) -> Self {
        var reader = Self()
        for (index, line) in data.split(separator: 0x0A, omittingEmptySubsequences: false).enumerated() {
            reader.read(line, number: index + 1)
        }
        return reader
    }
}

extension SessionLog.Format {
    /// A reader that has read `data`, a log in this format.
    func reader(reading data: Data) -> any LogReader {
        switch self {
        case .claude: ClaudeLogReader.reading(data)
        case .codex: CodexTranscriptParser.Reader.reading(data)
        case .pi: PiTranscriptParser.Reader.reading(data)
        case .opencode: OpenCodeTranscriptParser.Reader.reading(data)
        }
    }
}
