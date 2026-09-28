import AppKit
import AppModel
import SwiftTerm
import SwiftUI

/// SwiftTerm's terminal fed one screen at a time, with no process behind it: keystrokes typed into it go nowhere (the
/// composer sends), and a new screen waits while the user has scrolled up (`TerminalFeed`).
struct TerminalScreenView: NSViewRepresentable {
    let screen: TerminalScreen
    @Environment(\.textScale) private var scale
    @Environment(\.colorScheme) private var colorScheme

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> TerminalView {
        let view = TerminalView(frame: .zero, font: nil)
        view.terminalDelegate = context.coordinator
        view.allowMouseReporting = false
        view.setAccessibilityLabel("Terminal")
        return view
    }

    func updateNSView(_ view: TerminalView, context: Context) {
        let coordinator = context.coordinator
        let size = 12 * scale
        if coordinator.fontSize != size {
            coordinator.fontSize = size
            view.font = NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        }
        if coordinator.colorScheme != colorScheme {
            coordinator.colorScheme = colorScheme
            // SwiftTerm keeps fixed colours, so the dynamic system colours are resolved for the current appearance.
            view.effectiveAppearance.performAsCurrentDrawingAppearance {
                view.nativeForegroundColor = NSColor.textColor.usingColorSpace(.sRGB) ?? .textColor
                view.nativeBackgroundColor = NSColor.textBackgroundColor.usingColorSpace(.sRGB) ?? .textBackgroundColor
            }
        }
        coordinator.show(screen, in: view)
    }

    @MainActor
    final class Coordinator: NSObject, @preconcurrency TerminalViewDelegate {
        var fontSize: Double?
        var colorScheme: ColorScheme?
        private var feed = TerminalFeed()

        func show(_ screen: TerminalScreen, in view: TerminalView) {
            if let bytes = feed.receive(screen) {
                view.feed(byteArray: bytes[...])
            }
        }

        func scrolled(source: TerminalView, position: Double) {
            if let bytes = feed.scrolled(toBottom: !source.canScroll || position >= 1) {
                source.feed(byteArray: bytes[...])
            }
        }

        func send(source: TerminalView, data: ArraySlice<UInt8>) {}
        func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {}
        func setTerminalTitle(source: TerminalView, title: String) {}
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
        func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}
        func clipboardCopy(source: TerminalView, content: Data) {}
    }
}
