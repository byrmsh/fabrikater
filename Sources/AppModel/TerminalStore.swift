import FabrikaterCore
import HerdrKit
import Observation

/// One window's terminal view of a pane (M4): the pane's recent output, re-read every `interval` while the view is on
/// screen and not at all otherwise (docs/architecture.md, "Terminal read"). While reads fail, they back off.
@MainActor
@Observable
public final class TerminalStore {
    /// How many lines of screen and scrollback each read asks for.
    public static let lines = 400

    public private(set) var paneID: PaneID?
    /// The pane's width in cells, which the view is sized to; nil when Herdr's layout does not say.
    public private(set) var columns: Int?
    /// The last screen read; kept when a later read fails, and dropped when another pane is shown.
    public private(set) var screen: TerminalScreen?
    /// Why the last read failed; the screen shown is then stale.
    public private(set) var failure: String?
    /// The terminal view is on screen.
    public private(set) var isVisible = false

    private let reader: any TerminalReader
    private let interval: Duration
    private let backoff: Backoff
    private let pause: Pause
    @ObservationIgnored private(set) var pollTask: Task<Void, Never>?

    /// - Parameters:
    ///   - backoff: the waits after failed reads in a row, when longer than `interval`.
    ///   - pause: waits between reads; tests pass one they release by hand.
    public init(
        reader: any TerminalReader,
        interval: Duration = .milliseconds(1200),
        backoff: Backoff = Backoff(),
        pause: @escaping Pause = taskSleep
    ) {
        self.reader = reader
        self.interval = interval
        self.backoff = backoff
        self.pause = pause
    }

    /// True while reads repeat.
    public var isPolling: Bool { pollTask != nil }

    /// What the view shows: the last screen (stale while `failure` is set), why none could be read, that the first
    /// read is on its way, or that there is no pane.
    public var content: TerminalContent {
        if let screen { return .screen(screen, stale: failure) }
        if let failure { return .unavailable(title: "Terminal Unavailable", reason: failure) }
        return paneID == nil ? .gone("This pane is no longer in Herdr.") : .reading("Reading the terminal…")
    }

    /// Shows `pane`'s terminal, or none, `columns` cells wide.
    func show(_ pane: PaneID?, columns: Int? = nil) {
        if columns != self.columns { self.columns = columns }
        guard pane != paneID else { return }
        paneID = pane
        screen = nil
        failure = nil
        restart()
    }

    /// Stops reading, for good: the window or the host it read from is gone.
    func close() {
        isVisible = false
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
        let backoff = backoff
        pollTask = Task { [weak self] in
            var backoff = backoff
            while !Task.isCancelled {
                let result: Result<String, any Error>
                do {
                    result = .success(try await reader.recent(of: pane, lines: Self.lines))
                } catch {
                    result = .failure(error)
                }
                guard !Task.isCancelled, let self else { return }
                self.receive(result)
                let wait: Duration
                switch result {
                case .success:
                    backoff.reset()
                    wait = interval
                case .failure:
                    wait = max(interval, backoff.delay())
                }
                do {
                    try await pause(wait)
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

/// What a terminal view shows (`TerminalStore.content`).
public enum TerminalContent: Equatable, Sendable {
    /// The pane's screen, with why it is stale when the last read failed.
    case screen(TerminalScreen, stale: String?)
    /// No screen was read yet and the last read failed.
    case unavailable(title: String, reason: String)
    /// The first read is on its way.
    case reading(String)
    /// The window has no pane to read.
    case gone(String)
}

/// Reads every pane as blank: the default for tests that do not look at the terminal.
public struct BlankTerminalReader: TerminalReader {
    public init() {}

    public func recent(of pane: PaneID, lines: Int) async throws -> String { "" }
}
