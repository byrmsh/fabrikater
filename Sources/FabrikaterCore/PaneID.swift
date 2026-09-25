/// A Herdr pane id such as `w3:pQ`.
///
/// Pane ids end up as arguments of remote shell commands, so a value of this type is always valid:
/// `^w[0-9A-Za-z]+:p[0-9A-Za-z]+$`, ASCII only.
public struct PaneID: Hashable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init?(_ rawValue: String) {
        guard Self.isValid(rawValue) else { return nil }
        self.rawValue = rawValue
    }

    public var description: String { rawValue }

    private static func isValid(_ value: String) -> Bool {
        let parts = value.utf8.split(separator: UInt8(ascii: ":"), omittingEmptySubsequences: false)
        guard parts.count == 2 else { return false }
        return isPrefixedAlphanumeric(parts[0], prefix: "w") && isPrefixedAlphanumeric(parts[1], prefix: "p")
    }

    private static func isPrefixedAlphanumeric(_ bytes: Substring.UTF8View, prefix: Unicode.Scalar) -> Bool {
        guard bytes.first == UInt8(ascii: prefix), bytes.count > 1 else { return false }
        return bytes.dropFirst().allSatisfy { byte in
            (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte)
                || (UInt8(ascii: "A")...UInt8(ascii: "Z")).contains(byte)
                || (UInt8(ascii: "a")...UInt8(ascii: "z")).contains(byte)
        }
    }
}

extension PaneID: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let id = PaneID(rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid pane id \(rawValue.debugDescription)"
            )
        }
        self = id
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
