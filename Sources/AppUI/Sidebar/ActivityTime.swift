import AppModel
import SwiftUI

/// A row's last activity ("3m"), re-read every minute so it ages without a new herd.
struct ActivityTime: View {
    let activity: (Date) -> ActivityText?

    var body: some View {
        TimelineView(.everyMinute) { context in
            if let text = activity(context.date) {
                Text(text.short)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(text.spoken)
            }
        }
    }
}
