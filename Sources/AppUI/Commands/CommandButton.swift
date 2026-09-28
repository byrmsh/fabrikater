import AppModel
import SwiftUI

/// A menu item for one command: its title, its shortcut from `Keymap`, and whether the front window allows it now. A
/// command that switches a setting shows a checkmark.
struct CommandButton: View {
    let target: MenuTarget
    let command: AppCommand

    var body: some View {
        if let isChecked = target.isChecked(command) {
            Toggle(target.title(of: command), isOn: Binding(get: { isChecked }, set: { _ in target.perform(command) }))
                .keyboardShortcut(Keymap.chord(for: command)?.shortcut)
                .disabled(!target.isEnabled(command))
        } else {
            Button(target.title(of: command)) { target.perform(command) }
                .keyboardShortcut(Keymap.chord(for: command)?.shortcut)
                .disabled(!target.isEnabled(command))
        }
    }
}
