import AppModel
import SwiftUI

/// The menu bar item itself: the bell, and the count while panes wait.
struct NeedsYouMenuBarLabel: View {
    let status: MenuBarStatus

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: status.symbol)
            if let count = status.count {
                Text(count)
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(status.spokenLabel)
    }
}
