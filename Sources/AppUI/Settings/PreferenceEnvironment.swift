import AppModel
import SwiftUI

/// The terminal's font size in points: the Settings size times the window's text steps.
private struct TerminalFontSizeKey: EnvironmentKey {
    static let defaultValue = Double(Preferences.defaultTerminalTextSize)
}

/// Which key sends the composer's text (Settings).
private struct SendKeyKey: EnvironmentKey {
    static let defaultValue = SendKey.return
}

extension EnvironmentValues {
    var terminalFontSize: Double {
        get { self[TerminalFontSizeKey.self] }
        set { self[TerminalFontSizeKey.self] = newValue }
    }

    var sendKey: SendKey {
        get { self[SendKeyKey.self] }
        set { self[SendKeyKey.self] = newValue }
    }
}

extension View {
    /// The window's text sizes and send key, from the Settings window and the window's ⌘+ / ⌘− steps.
    func preferred(_ preferences: Preferences, scale: TextScale) -> some View {
        environment(\.textScale, preferences.conversationScale(scale))
            .environment(\.terminalFontSize, preferences.terminalFontSize(scale))
            .environment(\.sendKey, preferences.sendKey)
    }
}
