import FabrikaterCore
import HerdrKit
import Observation

/// A window showing one pane's conversation (B15). `AppStore.paneWindow(_:)` makes it and keeps it up to date with the
/// herd for as long as the window holds it.
@MainActor
@Observable
public final class PaneWindowStore {
    public let paneID: PaneID
    /// The pane's title, location, agent and status; the last known ones once the pane is gone.
    public private(set) var header: PaneHeader?
    /// Set once Herdr no longer has the pane; the conversation stays as last read.
    public private(set) var notice: String?
    /// This window's conversation, composer, prompt card, terminal and panels.
    public let detail: PaneDetailStores

    init(paneID: PaneID, detail: PaneDetailStores) {
        self.paneID = paneID
        self.detail = detail
    }

    /// The pane as the herd has it now with its header, or nil when it is gone.
    func show(_ pane: (pane: Herd.Pane, header: PaneHeader)?, isOnline: Bool) {
        detail.showInput(pane?.pane, isOnline: isOnline)
        guard let pane else {
            notice = "This pane is no longer in Herdr."
            detail.terminal.show(nil)
            return
        }
        notice = nil
        header = pane.header
        detail.show(pane.pane)
    }

    /// Handles the pane detail's commands for this window; ignores every other.
    public func perform(_ command: AppCommand) {
        detail.perform(command, hasPane: header != nil)
    }

    public func isEnabled(_ command: AppCommand) -> Bool {
        detail.isEnabled(command, hasPane: header != nil) ?? false
    }

    /// Whether a menu item that switches one of this window's panels shows a checkmark; nil for any other command.
    public func isChecked(_ command: AppCommand) -> Bool? {
        detail.isChecked(command)
    }
}

/// The open pane windows, held weakly so closing a window frees its store.
struct PaneWindowList {
    private struct Entry {
        weak var store: PaneWindowStore?
    }

    private var entries: [Entry] = []

    var stores: [PaneWindowStore] { entries.compactMap(\.store) }

    mutating func add(_ store: PaneWindowStore) {
        entries.removeAll { $0.store == nil }
        entries.append(Entry(store: store))
    }
}
