import FabrikaterCore
import TranscriptKit

/// The last few conversations read, so going back to a pane shows its conversation at once while it re-reads.
struct TranscriptCache {
    let limit: Int
    private var transcripts: [SessionLog: Transcript] = [:]
    /// Least recently stored first.
    private var order: [SessionLog] = []

    init(limit: Int = 16) {
        self.limit = max(limit, 1)
    }

    subscript(log: SessionLog) -> Transcript? {
        transcripts[log]
    }

    mutating func store(_ transcript: Transcript, for log: SessionLog) {
        order.removeAll { $0 == log }
        order.append(log)
        transcripts[log] = transcript
        while order.count > limit {
            transcripts[order.removeFirst()] = nil
        }
    }
}
