import AppModel
import SwiftUI

/// A menu item for one command: its title, its shortcut from `Keymap`, and whether the store allows it now. A command
/// that switches a setting shows a checkmark.
struct CommandButton: View {
    let store: AppStore
    let command: AppCommand

    var body: some View {
        if let isChecked = store.isChecked(command) {
            Toggle(store.title(of: command), isOn: Binding(get: { isChecked }, set: { _ in store.perform(command) }))
                .keyboardShortcut(Keymap.chord(for: command)?.shortcut)
                .disabled(!store.isEnabled(command))
        } else {
            Button(store.title(of: command)) { store.perform(command) }
                .keyboardShortcut(Keymap.chord(for: command)?.shortcut)
                .disabled(!store.isEnabled(command))
        }
    }
}
