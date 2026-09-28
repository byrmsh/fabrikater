import AppModel
import SwiftUI

/// The terminal panel: the pane's recent output with its colours, read-only (docs/design.md, "Terminal view"). Its
/// store reads the pane only while this view is on screen.
struct TerminalPanel: View {
    let terminal: TerminalStore
    let perform: @MainActor (AppCommand) -> Void

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear { perform(.setTerminalVisible(true)) }
            .onDisappear { perform(.setTerminalVisible(false)) }
    }

    @ViewBuilder private var content: some View {
        if let screen = terminal.screen {
            TerminalScreenView(screen: screen)
                .overlay(alignment: .bottom) {
                    if let failure = terminal.failure {
                        StaleBanner(message: failure)
                    }
                }
        } else if let failure = terminal.failure {
            ContentUnavailableView("Terminal Unavailable", systemImage: "terminal", description: Text(failure))
        } else if let placeholder = terminal.placeholder, terminal.paneID != nil {
            ProgressView(placeholder)
        } else if let placeholder = terminal.placeholder {
            ContentUnavailableView(placeholder, systemImage: "rectangle.slash")
        }
    }
}
