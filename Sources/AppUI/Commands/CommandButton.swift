import AppModel
import SwiftUI

/// A menu item for one command: its title, its shortcut from `Keymap`, and whether the store allows it now.
struct CommandButton: View {
    let store: AppStore
    let command: AppCommand

    var body: some View {
        Button(command.title) { store.perform(command) }
            .keyboardShortcut(Keymap.chord(for: command)?.shortcut)
            .disabled(!store.isEnabled(command))
    }
}
