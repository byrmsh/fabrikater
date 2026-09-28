import AppModel
import SwiftUI

/// The terminal as wide as the pane in Herdr, so a line the pane shows whole is never cut at the window's edge: when
/// the window is narrower the terminal scrolls sideways, and when it is wider the terminal fills it. The text keeps a
/// margin from the edges in the terminal's own background.
struct PaneWideTerminal: View {
    let screen: TerminalScreen
    /// The pane's width in cells; nil fits the terminal to the window.
    let columns: Int?
    @Environment(\.textScale) private var scale

    private static let inset: CGFloat = 8

    var body: some View {
        GeometryReader { proxy in
            let available = CGSize(
                width: max(proxy.size.width - 2 * Self.inset, 0), height: max(proxy.size.height - 2 * Self.inset, 0))
            ScrollView(.horizontal) {
                TerminalScreenView(screen: screen)
                    .frame(width: max(available.width, paneWidth), height: available.height)
                    .padding(Self.inset)
            }
            .scrollDisabled(paneWidth <= available.width)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var paneWidth: CGFloat {
        columns.map { TerminalScreenView.width(columns: $0, scale: scale) } ?? 0
    }
}
