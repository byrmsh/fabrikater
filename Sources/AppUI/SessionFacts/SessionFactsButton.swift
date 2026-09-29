import AppModel
import SwiftUI

/// The toolbar's status, as a button that shows or hides the Session Info panel (B11), in the main window and pane
/// windows.
struct SessionFactsButton: View {
    let model: any PaneDetailModel
    let header: PaneHeader

    var body: some View {
        Button {
            model.perform(.togglePanel(.facts))
        } label: {
            PaneStatusView(header: header)
        }
        .disabled(!model.isEnabled(.togglePanel(.facts)))
        .accessibilityLabel(header.summary)
        .accessibilityHint(AppCommand.togglePanel(.facts).title)
        .help(header.summary)
    }
}
