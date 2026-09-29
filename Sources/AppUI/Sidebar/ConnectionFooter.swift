import AppModel
import SwiftUI

/// Connected, connecting, or offline with the last error (docs/design.md, "Connection state").
struct ConnectionFooter: View {
    let connection: ConnectionState

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbolName)
                .foregroundStyle(tint)
            Text(connection.title)
                .lineLimit(1)
            Spacer()
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .help(detail)
        // One element that reads the state and, when offline, why, which otherwise shows only as a help tag.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(connection.title)
        .accessibilityValue(connection.failure ?? "")
    }

    private var symbolName: String {
        switch connection {
        case .connecting: "circle.dotted"
        case .connected: "circle.fill"
        case .stale, .offline: "exclamationmark.triangle.fill"
        }
    }

    private var tint: Color {
        switch connection {
        case .connecting: .secondary
        case .connected: .green
        case .stale, .offline: .orange
        }
    }

    private var detail: String {
        connection.failure ?? connection.title
    }
}
