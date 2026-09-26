import FabrikaterCore
import HerdrKit

/// Moves Herdr's own focus to the pane selected in the app, so the terminal on the host shows the same pane.
///
/// Stepping through the sidebar selects many panes quickly; only the one the selection settles on is focused.
@MainActor
final class FocusSync {
    private let control: any HerdrControl
    private let settle: Duration
    private let log = Log(category: "AppModel")
    private(set) var task: Task<Void, Never>?

    init(control: any HerdrControl, settle: Duration = .milliseconds(200)) {
        self.control = control
        self.settle = settle
    }

    func follow(_ pane: PaneID?) {
        task?.cancel()
        guard let pane else { return }
        task = Task { [control, settle, log] in
            do {
                try await Task.sleep(for: settle)
                try await control.perform([.focus(pane)])
            } catch {
                // A newer selection cancelled this one, possibly mid-command.
                guard !Task.isCancelled else { return }
                log.error("focusing \(pane) in Herdr failed: \(error)")
            }
        }
    }
}
