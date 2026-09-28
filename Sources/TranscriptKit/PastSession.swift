import FabrikaterCore
import Foundation
import HostKit

/// One of the conversations kept beside a pane's live Claude log: an earlier session started in the same working
/// directory, or the live one itself.
public struct PastSession: Hashable, Sendable, Identifiable {
    public let log: SessionLog
    /// When the log was last written.
    public let modified: Date
    public let bytes: Int
    /// The session's first prompt on one line.
    public let title: String
    /// True for the pane's own, live log.
    public let isCurrent: Bool

    public var id: SessionID { log.session }

    public init(log: SessionLog, modified: Date, bytes: Int, title: String, isCurrent: Bool) {
        self.log = log
        self.modified = modified
        self.bytes = bytes
        self.title = title
        self.isCurrent = isCurrent
    }
}

extension PastSession {
    /// The sessions in `HostCommand.claudeSessions`'s output, newest first as listed. A log without a prompt (a
    /// hand-over stub, a session closed before its first message) is left out, unless it is the live one.
    public static func parse(listing: Data) -> [PastSession] {
        let lines = listing.split(separator: UInt8(ascii: "\n"))
        guard let first = lines.first else { return [] }
        let current = String(decoding: first, as: UTF8.self)
        return lines.dropFirst().compactMap { line in
            let fields = line.split(separator: UInt8(ascii: "\t"), omittingEmptySubsequences: false)
            guard fields.count >= 3,
                let seconds = TimeInterval(String(decoding: fields[0], as: UTF8.self)),
                let bytes = Int(String(decoding: fields[1], as: UTF8.self)),
                case let name = String(decoding: fields[2], as: UTF8.self), name.hasSuffix(".jsonl"),
                let session = SessionID(String(name.dropLast(6)))
            else { return nil }
            let isCurrent = name == current
            let title = fields.dropFirst(3).lazy.compactMap { title(ofUserRow: $0) }.first
            guard title != nil || isCurrent else { return nil }
            return PastSession(
                log: SessionLog(format: .claude, session: session), modified: Date(timeIntervalSince1970: seconds),
                bytes: bytes, title: title ?? "", isCurrent: isCurrent)
        }
    }

    /// The prompt a Claude user row carries, on one line, or nil when it has none. A row cut short by the listing is
    /// read up to the cut.
    static func title(ofUserRow row: Data.SubSequence) -> String? {
        let text: String?
        if let object = try? JSONSerialization.jsonObject(with: row) as? [String: Any] {
            let content = (object["message"] as? [String: Any])?["content"]
            text =
                content as? String
                ?? (content as? [[String: Any]])?.first { $0["type"] as? String == "text" }?["text"] as? String
        } else {
            text =
                Self.leadingString(after: #""content":""#, in: row) ?? Self.leadingString(after: #""text":""#, in: row)
        }
        guard let text, !text.hasPrefix("<") else { return nil }
        let line = TextRules.oneLine(TextRules.stripANSI(text))
        return line.isEmpty ? nil : line
    }

    /// The JSON string that starts right after the first `key` in `row`, decoded up to its closing quote or the end of
    /// the row.
    static func leadingString(after key: String, in row: Data.SubSequence) -> String? {
        guard let range = row.firstRange(of: Data(key.utf8)) else { return nil }
        var scalars = String.UnicodeScalarView()
        let bytes = Array(row[range.upperBound...])
        var index = 0
        var pendingHigh: UInt32?
        func next() -> UInt8? {
            guard index < bytes.count else { return nil }
            defer { index += 1 }
            return bytes[index]
        }
        // Decode the UTF-8 runs between escapes whole, so multi-byte characters survive.
        var run: [UInt8] = []
        func flush() {
            scalars.append(contentsOf: String(decoding: run, as: UTF8.self).unicodeScalars)
            run.removeAll()
        }
        loop: while let byte = next() {
            switch byte {
            case UInt8(ascii: "\""):
                break loop
            case UInt8(ascii: "\\"):
                flush()
                guard let escape = next() else { break loop }
                switch escape {
                case UInt8(ascii: "n"): scalars.append("\n")
                case UInt8(ascii: "t"): scalars.append("\t")
                case UInt8(ascii: "r"): scalars.append("\r")
                case UInt8(ascii: "b"), UInt8(ascii: "f"): scalars.append(" ")
                case UInt8(ascii: "u"):
                    guard index + 4 <= bytes.count,
                        let code = UInt32(String(decoding: bytes[index..<index + 4], as: UTF8.self), radix: 16)
                    else { break loop }
                    index += 4
                    if (0xD800..<0xDC00).contains(code) {
                        pendingHigh = code
                    } else if (0xDC00..<0xE000).contains(code), let high = pendingHigh {
                        pendingHigh = nil
                        let value = 0x10000 + ((high - 0xD800) << 10) + (code - 0xDC00)
                        Unicode.Scalar(value).map { scalars.append($0) }
                    } else {
                        Unicode.Scalar(code).map { scalars.append($0) }
                    }
                default: scalars.append(Unicode.Scalar(escape))
                }
            default:
                run.append(byte)
            }
        }
        flush()
        return String(scalars)
    }
}

/// Lists the sessions beside a pane's live log. `HostTranscriptService` is the real one.
public protocol SessionHistory: Sendable {
    /// The sessions kept beside `log`, newest first, the live one among them.
    func pastSessions(besides log: SessionLog) async throws -> [PastSession]
}

extension HostTranscriptService: SessionHistory {
    /// Only Claude keeps its sessions per working directory; other formats list nothing yet.
    public func pastSessions(besides log: SessionLog) async throws -> [PastSession] {
        guard log.format == .claude else { return [] }
        do {
            return PastSession.parse(listing: try await runner.run(.claudeSessions(log.session)))
        } catch HostError.exited(HostCommand.notFoundStatus, _) {
            throw TranscriptError.noLog
        }
    }
}
