import AppModel
import SwiftUI

extension AttributedString {
    /// `tokens` joined, each coloured from `CodePalette` for the appearance; plain runs keep the view's foreground.
    init(code tokens: [CodeToken], dark: Bool) {
        self.init()
        for token in tokens {
            var run = AttributedString(token.text)
            if let rgb = CodePalette.color(for: token.kind, dark: dark) {
                run.foregroundColor = Color(
                    .sRGB, red: Double(rgb.red) / 255, green: Double(rgb.green) / 255, blue: Double(rgb.blue) / 255)
            }
            append(run)
        }
    }
}
