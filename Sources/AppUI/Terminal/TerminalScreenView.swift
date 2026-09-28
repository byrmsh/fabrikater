import AppKit
import AppModel
import SwiftTerm
import SwiftUI

/// SwiftTerm's terminal fed one screen at a time, with no process behind it: keystrokes typed into it go nowhere (the
/// composer sends), and a new screen waits while the user has scrolled up (`TerminalFeed`).
struct TerminalScreenView: NSViewRepresentable {
    let screen: TerminalScreen
    @Environment(\.terminalFontSize) private var fontSize
    @Environment(\.colorScheme) private var colorScheme

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> SnapshotTerminalView {
        let view = SnapshotTerminalView(frame: .zero, font: nil)
        view.terminalDelegate = context.coordinator
        view.onResize = { [weak view, coordinator = context.coordinator] in
            if let view { coordinator.resized(view) }
        }
        view.allowMouseReporting = false
        view.setAccessibilityLabel("Terminal")
        return view
    }

    func updateNSView(_ view: SnapshotTerminalView, context: Context) {
        let coordinator = context.coordinator
        if coordinator.fontSize != fontSize {
            coordinator.fontSize = fontSize
            view.font = Self.font(size: fontSize)
            coordinator.resized(view)
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

    static func font(size: Double) -> NSFont {
        NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }

    /// The frame width that fits `columns` cells: SwiftTerm's cell is the advance of "W", and its scroller sits
    /// beside the cells. One point spare keeps rounding from losing the last column.
    static func width(columns: Int, fontSize: Double) -> CGFloat {
        let font = font(size: fontSize)
        let cell = font.advancement(forGlyph: font.glyph(withName: "W")).width
        let scroller = NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy)
        return ceil(cell * CGFloat(columns) + scroller) + 1
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

        func resized(_ view: TerminalView) {
            if let bytes = feed.resized() {
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

/// A `TerminalView` that says when its width in columns changes, which happens first when SwiftUI lays it out: a screen
/// fed before then was clipped to the few columns of an empty frame. A sideways scroll passes through it to the scroll
/// view around it: SwiftTerm drops those, and its `scrollWheel` cannot be overridden from outside its module.
final class SnapshotTerminalView: TerminalView {
    var onResize: (() -> Void)?

    override func hitTest(_ point: NSPoint) -> NSView? {
        if let event = NSApp.currentEvent, event.type == .scrollWheel,
            abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY)
        {
            return nil
        }
        return super.hitTest(point)
    }

    override func setFrameSize(_ newSize: NSSize) {
        let columns = getTerminal().cols
        super.setFrameSize(newSize)
        if getTerminal().cols != columns {
            onResize?()
        }
    }
}
