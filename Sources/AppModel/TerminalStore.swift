import FabrikaterCore
import HerdrKit
import Observation

/// One window's terminal view of a pane (M4): the pane's recent output, re-read every `interval` while the view is on
/// screen and not at all otherwise (docs/architecture.md, "Terminal read").
@MainActor
@Observable
public final class TerminalStore {
    /// How many lines of screen and scrollback each read asks for.
    public static let lines = 400

    public private(set) var paneID: PaneID?
    /// The last screen read; kept when a later read fails, and dropped when another pane is shown.
    public private(set) var screen: TerminalScreen?
    /// Why the last read failed; the screen shown is then stale.
    public private(set) var failure: String?
    /// The terminal view is on screen.
    public private(set) var isVisible = false

    private let reader: any TerminalReader
    private let interval: Duration
    private let pause: @Sendable (Duration) async throws -> Void
    @ObservationIgnored private(set) var pollTask: Task<Void, Never>?

    /// - Parameter pause: waits between reads; tests pass one they release by hand.
    public init(
        reader: any TerminalReader,
        interval: Duration = .milliseconds(1200),
        pause: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.reader = reader
        self.interval = interval
        self.pause = pause
    }

    /// True while reads repeat.
    public var isPolling: Bool { pollTask != nil }

    /// What the view says instead of a screen: nothing to read, or the first read still on its way. Nil once a screen
    /// or a failure arrived.
    public var placeholder: String? {
        guard screen == nil, failure == nil else { return nil }
        return paneID == nil ? "This pane is no longer in Herdr." : "Reading the terminal…"
    }

    /// Shows `pane`'s terminal, or none.
    func show(_ pane: PaneID?) {
        guard pane != paneID else { return }
        paneID = pane
        screen = nil
        failure = nil
        restart()
    }

    /// The view appeared or disappeared.
    func setVisible(_ visible: Bool) {
        guard visible != isVisible else { return }
        isVisible = visible
        restart()
    }

    private func restart() {
        pollTask?.cancel()
        pollTask = nil
        guard isVisible, let pane = paneID else { return }
        let reader = reader
        let interval = interval
        let pause = pause
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                let result: Result<String, any Error>
                do {
                    result = .success(try await reader.recent(of: pane, lines: Self.lines))
                } catch {
                    result = .failure(error)
                }
                guard !Task.isCancelled, let self else { return }
                self.receive(result)
                do {
                    try await pause(interval)
                } catch {
                    return
                }
            }
        }
    }

    private func receive(_ result: Result<String, any Error>) {
        switch result {
        case .success(let ansi):
            let screen = TerminalScreen(ansi: ansi)
            if screen != self.screen { self.screen = screen }
            failure = nil
        case .failure(let error):
            failure = "The terminal could not be read: \(error)"
        }
    }
}

/// Reads every pane as blank: the default for tests that do not look at the terminal.
public struct BlankTerminalReader: TerminalReader {
    public init() {}

    public func recent(of pane: PaneID, lines: Int) async throws -> String { "" }
}
