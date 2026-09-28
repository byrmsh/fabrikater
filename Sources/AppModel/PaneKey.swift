import HerdrKit

/// The keys the composer's key bar sends to the pane (docs/design.md, "Composer").
public enum PaneKey: String, CaseIterable, Hashable, Sendable {
    case escape
    case ctrlC
    case tab
    case shiftTab
    case up
    case down
    case enter

    /// The button's text.
    public var title: String {
        switch self {
        case .escape: "Esc"
        case .ctrlC: "⌃C"
        case .tab: "Tab"
        case .shiftTab: "⇧Tab"
        case .up: "↑"
        case .down: "↓"
        case .enter: "Return"
        }
    }

    /// The key's full name: the menu item's title and the button's VoiceOver label.
    public var name: String {
        switch self {
        case .escape: "Escape"
        case .ctrlC: "Control-C"
        case .tab: "Tab"
        case .shiftTab: "Shift-Tab"
        case .up: "Up Arrow"
        case .down: "Down Arrow"
        case .enter: "Return"
        }
    }

    /// The button's help tag.
    public var help: String { "Send \(name) to the pane" }

    /// The Pane menu's submenu of keys.
    public static let menuTitle = "Send Key"

    var key: HerdrRequest.Key {
        switch self {
        case .escape: .escape
        case .ctrlC: .ctrlC
        case .tab: .tab
        case .shiftTab: .shiftTab
        case .up: .up
        case .down: .down
        case .enter: .enter
        }
    }
}
