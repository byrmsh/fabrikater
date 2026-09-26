import FabrikaterCore
import TranscriptKit

/// The last few conversations read, so going back to a pane shows its conversation at once while it re-reads.
struct TranscriptCache {
    let limit: Int
    private var transcripts: [SessionID: Transcript] = [:]
    /// Least recently stored first.
    private var order: [SessionID] = []

    init(limit: Int = 16) {
        self.limit = max(limit, 1)
    }

    subscript(session: SessionID) -> Transcript? {
        transcripts[session]
    }

    mutating func store(_ transcript: Transcript, for session: SessionID) {
        order.removeAll { $0 == session }
        order.append(session)
        transcripts[session] = transcript
        while order.count > limit {
            transcripts[order.removeFirst()] = nil
        }
    }
}
