/// An agent's session id from the snapshot's `agent_session.value`, such as a Claude session UUID.
///
/// Session ids end up in remote shell commands, so a value of this type is always valid: a UUID
/// (Claude, Codex, pi, Grok) or an OpenCode id `ses_` plus 8 to 64 ASCII letters and digits (docs/parsing.md 1.1).
/// Decoding checks it the same way, so a restored window cannot carry an invalid id.
public struct SessionID: Hashable, Sendable, Codable, CustomStringConvertible {
    public let rawValue: String

    public init?(_ rawValue: String) {
        guard Self.isUUID(rawValue) || Self.isOpenCodeID(rawValue) else { return nil }
        self.rawValue = rawValue
    }

    public var description: String { rawValue }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let id = SessionID(raw) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "not a session id")
        }
        self = id
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    private static func isUUID(_ value: String) -> Bool {
        let groups = value.utf8.split(separator: UInt8(ascii: "-"), omittingEmptySubsequences: false)
        guard groups.map(\.count) == [8, 4, 4, 4, 12] else { return false }
        return groups.allSatisfy { $0.allSatisfy(isHexDigit) }
    }

    private static func isOpenCodeID(_ value: String) -> Bool {
        guard value.hasPrefix("ses_") else { return false }
        let rest = value.utf8.dropFirst(4)
        return (8...64).contains(rest.count) && rest.allSatisfy(isAlphanumeric)
    }

    private static func isHexDigit(_ byte: UInt8) -> Bool {
        (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte)
            || (UInt8(ascii: "a")...UInt8(ascii: "f")).contains(byte)
            || (UInt8(ascii: "A")...UInt8(ascii: "F")).contains(byte)
    }

    private static func isAlphanumeric(_ byte: UInt8) -> Bool {
        (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte)
            || (UInt8(ascii: "A")...UInt8(ascii: "Z")).contains(byte)
            || (UInt8(ascii: "a")...UInt8(ascii: "z")).contains(byte)
    }
}
