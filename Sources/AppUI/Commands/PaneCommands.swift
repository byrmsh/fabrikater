import AppModel
import SwiftUI

/// The Pane menu: every pane command with its shortcut from `Keymap`, acting on the front window's pane.
@MainActor
public struct PaneCommands: Commands {
    let store: AppStore
    /// The pane window in front, if one is; nil while the main window is.
    @FocusedValue(PaneWindowStore.self) private var paneWindow
    @Environment(\.openWindow) private var openWindow

    public init(store: AppStore) {
        self.store = store
    }

    private var target: MenuTarget {
        MenuTarget(app: store, window: paneWindow)
    }

    public var body: some Commands {
        CommandMenu("Pane") {
            button(.openQuickSwitcher)
            Divider()
            button(.selectPreviousPane)
            button(.selectNextPane)
            Divider()
            ForEach(NeedsYou.numbers.filter { target.isEnabled(.selectNeedsYou($0)) }, id: \.self) { number in
                button(.selectNeedsYou(number))
            }
            Divider()
            button(.renamePane(nil))
            button(.togglePin(nil))
            button(.toggleHidden(nil))
            button(.toggleHiddenWorkspace(nil))
            button(.toggleNotifications(nil))
            Divider()
            button(.openInVSCode(nil))
            Button(AppCommand.openInNewWindow(nil).title) {
                if let id = target.windowPane {
                    openWindow(value: id)
                }
            }
            .disabled(!target.isEnabled(.openInNewWindow(nil)))
            Divider()
            button(.reloadConversation)
            button(.loadEarlier)
            button(.copyConversation)
            button(.toggleSessionFacts)
            Divider()
            button(.send)
            Menu(PaneKey.menuTitle) {
                ForEach(PaneKey.allCases, id: \.self) { key in
                    button(.sendKey(key))
                }
            }
            Menu(PromptCardStore.menuTitle) {
                ForEach(target.prompt.options) { option in
                    Button(option.title) { target.perform(.answerPrompt(option.number)) }
                        .disabled(!target.isEnabled(.answerPrompt(option.number)))
                }
            }
            .disabled(target.prompt.options.isEmpty)
        }
    }

    private func button(_ command: AppCommand) -> some View {
        CommandButton(target: target, command: command)
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
