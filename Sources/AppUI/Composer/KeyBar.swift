import AppModel
import SwiftUI

/// A row of single keys above the composer's field, sent to the pane as they are (docs/design.md, "Composer"). The
/// Pane menu's Send Key submenu has the same keys.
struct KeyBar: View {
    let composer: ComposerStore
    let perform: @MainActor (AppCommand) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(PaneKey.allCases, id: \.self) { key in
                Button(key.title) {
                    perform(.sendKey(key))
                }
                .disabled(!composer.canSend(key))
                .help(key.help)
                .accessibilityLabel(key.name)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(PaneKey.menuTitle)
    }
}
