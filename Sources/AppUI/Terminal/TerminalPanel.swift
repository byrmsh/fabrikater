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
        switch terminal.content {
        case .screen(let screen, let stale):
            PaneWideTerminal(screen: screen, columns: terminal.columns)
                .overlay(alignment: .bottom) {
                    if let stale {
                        StaleBanner(message: stale)
                    }
                }
        case .unavailable(let title, let reason):
            ContentUnavailableView(title, systemImage: "terminal", description: Text(reason))
        case .reading(let message):
            ProgressView(message)
        case .gone(let message):
            ContentUnavailableView(message, systemImage: "rectangle.slash")
        }
    }
}
