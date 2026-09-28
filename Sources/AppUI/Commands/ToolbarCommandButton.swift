import AppModel
import SwiftUI

/// A toolbar button for one command: its symbol, with the command's title as its label and help tag.
struct ToolbarCommandButton: View {
    let command: AppCommand
    let systemImage: String
    let isEnabled: Bool
    let perform: @MainActor (AppCommand) -> Void

    var body: some View {
        Button {
            perform(command)
        } label: {
            Label(command.title, systemImage: systemImage)
        }
        .disabled(!isEnabled)
        .help(command.title)
    }
}
