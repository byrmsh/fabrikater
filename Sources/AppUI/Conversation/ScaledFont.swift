import SwiftUI

/// The conversation's text size as a multiple of the system size, set once by `DetailView` from `AppStore.textScale`.
private struct TextScaleKey: EnvironmentKey {
    static let defaultValue = 1.0
}

extension EnvironmentValues {
    var textScale: Double {
        get { self[TextScaleKey.self] }
        set { self[TextScaleKey.self] = newValue }
    }
}

extension View {
    /// The system font for `style`, scaled by the conversation's text size.
    func scaledFont(_ style: Font.TextStyle, design: Font.Design = .default) -> some View {
        modifier(ScaledFont(style: style, design: design))
    }
}

private struct ScaledFont: ViewModifier {
    let style: Font.TextStyle
    let design: Font.Design
    @Environment(\.textScale) private var scale

    func body(content: Content) -> some View {
        content.font(.system(size: Self.macOSPointSize(style) * scale, design: design))
    }

    /// macOS's text style sizes, which do not follow Dynamic Type.
    private static func macOSPointSize(_ style: Font.TextStyle) -> Double {
        switch style {
        case .largeTitle: 26
        case .title: 22
        case .title2: 17
        case .title3: 15
        case .callout: 12
        case .subheadline: 11
        case .footnote: 10
        case .caption: 10
        case .caption2: 10
        default: 13
        }
    }
}
