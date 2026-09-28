import AppModel
import SwiftUI

/// The toolbar's Conversation | Terminal control; View ▸ Show Terminal (⌘T) does the same.
struct DetailPanelPicker: View {
    let layout: WorkspaceLayout
    let isEnabled: Bool
    let perform: @MainActor (AppCommand) -> Void

    var body: some View {
        Picker(AppCommand.toggleTerminal.title, selection: selection) {
            ForEach(DetailPanel.allCases, id: \.self) { panel in
                Text(panel.title).tag(panel)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
        .disabled(!isEnabled)
        .help("Show the conversation or the terminal (⌘T)")
    }

    private var selection: Binding<DetailPanel> {
        Binding(get: { layout.detail }, set: { perform(.showPanel($0)) })
    }
}
