/// The ssh destination, an alias from the user's `~/.ssh/config` such as `arch`.
///
/// Rejects anything ssh could read as an option or that holds whitespace or shell metacharacters.
public struct HostAlias: Hashable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init?(_ rawValue: String) {
        let allowed = rawValue.utf8.allSatisfy { byte in
            (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte)
                || (UInt8(ascii: "A")...UInt8(ascii: "Z")).contains(byte)
                || (UInt8(ascii: "a")...UInt8(ascii: "z")).contains(byte)
                || [UInt8(ascii: "-"), UInt8(ascii: "."), UInt8(ascii: "_"), UInt8(ascii: "@")].contains(byte)
        }
        guard allowed, !rawValue.isEmpty, !rawValue.hasPrefix("-") else { return nil }
        self.rawValue = rawValue
    }

    public var description: String { rawValue }
}
