/// A key plus modifiers, independent of any UI toolkit. `AppUI` turns it into a SwiftUI shortcut.
public struct KeyChord: Hashable, Sendable {
    public enum Key: Hashable, Sendable {
        case character(Character)
        case upArrow
        case downArrow
        case `return`
    }

    public struct Modifiers: OptionSet, Hashable, Sendable {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let command = Modifiers(rawValue: 1 << 0)
        public static let shift = Modifiers(rawValue: 1 << 1)
        public static let option = Modifiers(rawValue: 1 << 2)
        public static let control = Modifiers(rawValue: 1 << 3)
    }

    public var key: Key
    public var modifiers: Modifiers

    public init(_ key: Key, _ modifiers: Modifiers = .command) {
        self.key = key
        self.modifiers = modifiers
    }
}

/// The keyboard shortcut of each command that has one (docs/design.md, "Window").
public enum Keymap {
    public static let bindings: [AppCommand: KeyChord] = [
        .selectNextPane: KeyChord(.downArrow),
        .selectPreviousPane: KeyChord(.upArrow),
        .reloadConversation: KeyChord(.character("r")),
        .send: KeyChord(.return),
        .renamePane(nil): KeyChord(.character("r"), [.command, .shift]),
        .togglePin(nil): KeyChord(.character("p"), [.command, .shift]),
        .toggleShowHidden: KeyChord(.character("."), [.command, .shift]),
        .toggleSidebar: KeyChord(.character("s"), [.command, .control]),
        .biggerText: KeyChord(.character("+")),
        .smallerText: KeyChord(.character("-")),
        .actualSizeText: KeyChord(.character("0")),
        .openQuickSwitcher: KeyChord(.character("k")),
        .copyConversation: KeyChord(.character("c"), [.command, .shift]),
        .toggleSessionFacts: KeyChord(.character("i")),
        .toggleChanges: KeyChord(.character("0"), [.command, .option]),
        .toggleTerminal: KeyChord(.character("t")),
    ].merging(NeedsYou.numbers.map { (.selectNeedsYou($0), KeyChord(.character(Character(String($0))))) }) { $1 }

    public static func chord(for command: AppCommand) -> KeyChord? {
        bindings[command]
    }
}
