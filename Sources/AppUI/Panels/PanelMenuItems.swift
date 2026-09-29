import AppModel
import SwiftUI

/// The commands that arrange one panel: in its header's menu, its context menu and the View menu's submenu for it.
struct PanelMenuItems: View {
    let panel: InfoPanel
    let isEnabled: @MainActor (AppCommand) -> Bool
    let isChecked: @MainActor (AppCommand) -> Bool
    let perform: @MainActor (AppCommand) -> Void

    var body: some View {
        item(.movePanelUp(panel))
        item(.movePanelDown(panel))
        Divider()
        ForEach(PanelDock.allCases, id: \.self) { dock in
            let command = AppCommand.movePanel(panel, to: dock)
            Toggle(command.title, isOn: Binding(get: { isChecked(command) }, set: { _ in perform(command) }))
        }
    }

    private func item(_ command: AppCommand) -> some View {
        Button(command.title) { perform(command) }
            .disabled(!isEnabled(command))
    }
}
