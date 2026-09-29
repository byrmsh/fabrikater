import AppKit
import AppModel
import SwiftUI

extension View {
    /// Has VoiceOver say `text` each time it changes to something new, while `isActive` holds.
    func announcing(_ text: String?, when isActive: Bool = true) -> some View {
        onChange(of: text) { _, text in
            if let text, isActive {
                AccessibilityNotification.Announcement(text).post()
            }
        }
    }

    /// Has VoiceOver say each of `Announcement.changes` as the store's state moves on, while the app is frontmost;
    /// behind other apps the notifications speak for it.
    func announcingChanges(of state: Announcement.State) -> some View {
        onChange(of: state) { old, new in
            guard NSApp.isActive else { return }
            for text in Announcement.changes(from: old, to: new) {
                AccessibilityNotification.Announcement(text).post()
            }
        }
    }
}
