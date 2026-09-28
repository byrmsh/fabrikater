// M4: what the terminal view draws from each `herdr pane read`.

/// One read of a pane's recent output, as ANSI text.
public struct TerminalScreen: Equatable, Sendable {
    public let ansi: String

    public init(ansi: String) {
        self.ansi = ansi
    }

    /// What the terminal is fed to show this screen alone: a full reset (which also drops the last screen's
    /// scrollback), line wrapping off so a line wider than the view is clipped rather than breaking a TUI's layout, the
    /// cursor hidden since the read does not say where it is, then the text with every bare `\n` made `\r\n`.
    public var bytes: [UInt8] {
        var bytes = Array("\u{1B}c\u{1B}[?7l\u{1B}[?25l".utf8)
        var previous: UInt8 = 0
        for byte in ansi.utf8 {
            if byte == 0x0A && previous != 0x0D { bytes.append(0x0D) }
            bytes.append(byte)
            previous = byte
        }
        return bytes
    }
}

/// Decides when the terminal view feeds a new screen. Feeding resets the terminal, which scrolls it to the bottom, so
/// while the user has scrolled up to read older output the newest screen waits until they scroll back down.
public struct TerminalFeed: Sendable {
    private var shown: TerminalScreen?
    private var waiting: TerminalScreen?
    private var isAtBottom = true

    public init() {}

    /// The bytes to feed for `screen` now, or nil when it is already shown, or held while the user reads above.
    public mutating func receive(_ screen: TerminalScreen?) -> [UInt8]? {
        guard let screen, screen != shown else {
            waiting = nil
            return nil
        }
        guard isAtBottom else {
            waiting = screen
            return nil
        }
        shown = screen
        return screen.bytes
    }

    /// The terminal changed its number of columns: returns the shown screen's bytes to feed again, since lines that
    /// did not fit were clipped when they were fed.
    public func resized() -> [UInt8]? {
        shown?.bytes
    }

    /// The user scrolled; returns the held screen's bytes once they are back at the bottom.
    public mutating func scrolled(toBottom: Bool) -> [UInt8]? {
        isAtBottom = toBottom
        guard toBottom, let waiting else { return nil }
        self.waiting = nil
        shown = waiting
        return waiting.bytes
    }
}
