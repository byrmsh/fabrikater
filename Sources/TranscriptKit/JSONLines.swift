import Foundation

/// The rows of a JSONL log, as every parser reads them (docs/parsing.md section 2).
enum JSONLines {
    /// Each line that parses to a JSON object, with its bytes and 1-based line number. Blank lines, a clipped first
    /// line, a half-written last line and lines that are not objects are skipped.
    static func rows(in data: Data) -> [(line: Data.SubSequence, number: Int, row: [String: Any])] {
        data.split(separator: 0x0A, omittingEmptySubsequences: false).enumerated().compactMap { index, line in
            guard let row = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { return nil }
            return (line, index + 1, row)
        }
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
