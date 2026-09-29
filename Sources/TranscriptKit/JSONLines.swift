import Foundation

/// The rows of a JSONL log, as every parser reads them (docs/parsing.md section 2).
enum JSONLines {
    /// The line as a JSON object, or nil for a blank line, a clipped first line, a half-written last line or a line
    /// that is not an object.
    static func row(_ line: Data.SubSequence) -> [String: Any]? {
        try? JSONSerialization.jsonObject(with: line) as? [String: Any]
    }

    /// A stable id for a row that has none: a djb2 hash of its bytes, plus a count when the same bytes came before,
    /// so an entry keeps its id when the window read from the log moves (Collie's `codexCursor`).
    struct RowIDs {
        private var seen: [String: Int] = [:]

        mutating func next(for line: Data.SubSequence, prefix: String) -> String {
            var hash: UInt32 = 5381
            for byte in line {
                hash = (hash &<< 5) &+ hash &+ UInt32(byte)
            }
            let key = String(hash, radix: 36)
            let count = seen[key, default: 0]
            seen[key] = count + 1
            return count == 0 ? "\(prefix)-\(key)" : "\(prefix)-\(key)-\(count)"
        }
    }
}
