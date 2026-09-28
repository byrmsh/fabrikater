/// The colour of each token kind in light and dark mode, as sRGB. Plain text takes the view's own foreground.
/// Tuned from Xcode's default themes so each colour reads at 4.5:1 or better on a code block's background.
public enum CodePalette {
    public struct RGB: Equatable, Sendable {
        public var red: UInt8
        public var green: UInt8
        public var blue: UInt8

        public init(_ hex: UInt32) {
            red = UInt8(hex >> 16 & 0xFF)
            green = UInt8(hex >> 8 & 0xFF)
            blue = UInt8(hex & 0xFF)
        }
    }

    public static func color(for kind: CodeToken.Kind, dark: Bool) -> RGB? {
        switch kind {
        case .plain: nil
        case .keyword: RGB(dark ? 0xFF7AB2 : 0x9B2393)
        case .type, .meta: RGB(dark ? 0xDABAFF : 0x6C36A9)
        case .string: RGB(dark ? 0xFF8170 : 0xB21813)
        case .number: RGB(dark ? 0xD9C97C : 0x1C00CF)
        case .comment: RGB(dark ? 0x9CA8B3 : 0x536170)
        case .attribute: RGB(dark ? 0xFFA14F : 0x7A5A03)
        case .variable: RGB(dark ? 0x78C2B3 : 0x0F68A0)
        case .key: RGB(dark ? 0x6BDFFF : 0x0B6470)
        case .added: RGB(dark ? 0x56D364 : 0x116329)
        case .removed: RGB(dark ? 0xFF8A82 : 0xB91C26)
        }
    }
}
