import SwiftUI

/// A small accent-coloured dot at the end of a row whose agent finished a turn since it was last selected (B7), like
/// Mail's unread mark. Hidden from VoiceOver: the row's spoken label already says Unread.
struct UnreadDot: View {
    var body: some View {
        Circle()
            .fill(.tint)
            .frame(width: 6, height: 6)
            .accessibilityHidden(true)
    }
}
