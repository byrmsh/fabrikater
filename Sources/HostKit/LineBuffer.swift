import Foundation

/// Splits a byte stream into complete lines, holding a partial last line until its newline arrives.
public struct LineBuffer: Sendable {
    private var carry = Data()

    public init() {}

    /// Appends `chunk` and returns every line it completed, decoded as UTF-8, without the newline.
    public mutating func append(_ chunk: Data) -> [String] {
        carry.append(chunk)
        guard let lastNewline = carry.lastIndex(of: 0x0A) else { return [] }
        let complete = carry[carry.startIndex..<lastNewline]
        carry = Data(carry[carry.index(after: lastNewline)...])
        return complete.split(separator: 0x0A, omittingEmptySubsequences: false).map {
            String(decoding: $0, as: UTF8.self)
        }
    }

    /// The partial line left at the end of the stream, if any.
    public mutating func flush() -> String? {
        defer { carry = Data() }
        return carry.isEmpty ? nil : String(decoding: carry, as: UTF8.self)
    }
}
