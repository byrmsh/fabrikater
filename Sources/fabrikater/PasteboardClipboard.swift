import AppKit
import AppModel

/// The general pasteboard, as plain text.
@MainActor
final class PasteboardClipboard: Clipboard {
    func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
