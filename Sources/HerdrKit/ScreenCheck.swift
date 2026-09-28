import FabrikaterCore

/// What a pane's screen must show for a request to go ahead. The host runs the check in the same command that sends
/// the request, right before it, so a dialog that appears after the app last looked cannot take the keys
/// (docs/parsing.md 4.4, `HostCommand.herdrRequests`).
///
/// Rows are compared without spaces, tabs and no-break spaces, which terminals pad and wrap with, and without styling.
public struct ScreenCheck: Equatable, Sendable {
    /// Rows that must show one after another, among the screen's last `window` non-blank rows.
    public let rows: [String]
    /// Refused when one of the screen's last three non-blank rows contains one of these, case aside.
    public let refusing: [String]
    public let window: Int

    public init(rows: [String], refusing: [String], window: Int) {
        self.rows = rows.map(Self.compact).filter { !$0.isEmpty }
        self.refusing = refusing.map { Self.compact($0).lowercased() }.filter { !$0.isEmpty }
        self.window = max(window, self.rows.count)
    }

    /// The error code the host prints when the check fails.
    public static let failedCode = "screen_changed"

    /// The row as the host compares it: the same characters the host script removes (`HostCommand.herdrRequests`).
    static func compact(_ row: String) -> String {
        row.filter { !Self.ignored.contains($0) }
    }

    private static let ignored: Set<Character> = [" ", "\t", "\r", "\n", "\r\n", "\u{A0}"]

    /// `?<pane> <window> <refusing count> <row count>`, then the refusing phrases and the rows, one per line.
    func lines(for pane: PaneID) -> [String] {
        ["?\(pane.rawValue) \(window) \(refusing.count) \(rows.count)"] + refusing + rows
    }
}

extension HerdrError {
    /// The pane's screen failed a `ScreenCheck` on the host, so the request was not sent.
    public static let screenChanged = HerdrError("The pane's screen changed just before sending")
}
