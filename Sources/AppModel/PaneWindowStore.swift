import FabrikaterCore
import HerdrKit
import Observation
import TranscriptKit

/// A window showing one pane's conversation (B15). `AppStore.paneWindow(_:)` makes it and keeps it up to date with the
/// herd for as long as the window holds it.
@MainActor
@Observable
public final class PaneWindowStore {
    public let paneID: PaneID
    /// The pane's title, location, agent and status; the last known ones once the pane is gone.
    public private(set) var header: PaneHeader?
    public let conversation: ConversationStore
    /// Sends prompts to this window's pane; its draft is the pane's, shared with the main window.
    public let composer: ComposerStore
    /// Set once Herdr no longer has the pane; the conversation stays as last read.
    public private(set) var notice: String?
    /// This window's changes inspector and session facts popover.
    public private(set) var panels = PanePanels()

    private let clipboard: any Clipboard

    init(
        paneID: PaneID, transcripts: any TranscriptService, control: any HerdrControl, clipboard: any Clipboard,
        drafts: Drafts = Drafts()
    ) {
        self.paneID = paneID
        self.clipboard = clipboard
        conversation = ConversationStore(transcripts: transcripts)
        composer = ComposerStore(control: control, drafts: drafts)
    }

    /// The pane as the herd has it now with its header, or nil when it is gone.
    func show(_ pane: (pane: Herd.Pane, header: PaneHeader)?, isOnline: Bool) {
        composer.show(pane?.pane, isOnline: isOnline)
        guard let pane else {
            notice = "This pane is no longer in Herdr."
            return
        }
        notice = nil
        header = pane.header
        conversation.show(pane.pane)
    }

    /// Handles the conversation's commands, its panels and Send for this window; ignores every other.
    public func perform(_ command: AppCommand) {
        switch command {
        case .send: composer.send()
        case .toggleChanges, .setChangesShown, .toggleSessionFacts, .setSessionFactsShown:
            panels.perform(command, hasPane: header != nil)
        case .copyPath(let path): clipboard.copy(path)
        default: conversation.perform(command, clipboard: clipboard)
        }
    }

    public func isEnabled(_ command: AppCommand) -> Bool {
        switch command {
        case .send: composer.canSend
        case .copyPath: true
        default:
            PanePanels.isEnabled(command, hasPane: header != nil) ?? conversation.isEnabled(command) ?? false
        }
    }

    /// Whether a menu item that switches one of this window's panels shows a checkmark; nil for any other command.
    public func isChecked(_ command: AppCommand) -> Bool? {
        panels.isChecked(command)
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
