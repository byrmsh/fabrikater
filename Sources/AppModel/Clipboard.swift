/// Where the copy commands put text. The app writes the system pasteboard; tests read `InMemoryClipboard`.
@MainActor
public protocol Clipboard: AnyObject {
    func copy(_ text: String)
}

/// Keeps the last text copied: the default for tests.
@MainActor
public final class InMemoryClipboard: Clipboard {
    public private(set) var text: String?

    public init() {}

    public func copy(_ text: String) { self.text = text }
}
