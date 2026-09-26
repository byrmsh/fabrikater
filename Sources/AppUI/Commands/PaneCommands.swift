import AppModel
import SwiftUI

/// The Pane menu: every pane command with its shortcut from `Keymap`.
@MainActor
public struct PaneCommands: Commands {
    let store: AppStore

    public init(store: AppStore) {
        self.store = store
    }

    public var body: some Commands {
        CommandMenu("Pane") {
            button(.openQuickSwitcher)
            Divider()
            button(.selectPreviousPane)
            button(.selectNextPane)
            Divider()
            button(.renamePane(nil))
            Divider()
            button(.reloadConversation)
            Divider()
            button(.send)
        }
    }

    private func button(_ command: AppCommand) -> some View {
        CommandButton(store: store, command: command)
    }
}

extension KeyChord {
    var shortcut: KeyboardShortcut {
        let key: KeyEquivalent =
            switch self.key {
            case .character(let character): KeyEquivalent(character)
            case .upArrow: .upArrow
            case .downArrow: .downArrow
            case .return: .return
            }
        var eventModifiers: EventModifiers = []
        if modifiers.contains(.command) { eventModifiers.insert(.command) }
        if modifiers.contains(.shift) { eventModifiers.insert(.shift) }
        if modifiers.contains(.option) { eventModifiers.insert(.option) }
        if modifiers.contains(.control) { eventModifiers.insert(.control) }
        return KeyboardShortcut(key, modifiers: eventModifiers)
    }
}
