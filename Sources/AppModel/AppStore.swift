import FabrikaterCore
import Foundation
import HerdrKit
import Observation
import TranscriptKit

/// The selected pane's title and location (the window title) and its agent and status (the toolbar).
public struct PaneHeader: Equatable, Sendable {
    public var title: String
    /// "Workspace › Tab".
    public var location: String
    public var agent: String
    public var status: AgentStatus

    /// "Claude, Working": the toolbar's spoken label and help tag.
    public var summary: String { "\(agent), \(status.title)" }
}

/// The root store: the herd sidebar, the selection, and the commands that act on them.
@MainActor
@Observable
public final class AppStore {
    public private(set) var sections: [SidebarSection] = []
    public private(set) var connection = ConnectionState.connecting
    public private(set) var selection: PaneID?
    public private(set) var header: PaneHeader?
    /// The pane whose row shows the inline name field.
    public private(set) var renaming: PaneID?
    public private(set) var isSidebarVisible = true
    /// The conversation's text size.
    public private(set) var textScale = TextScale.actual
    /// The ⌘K switcher while it is open.
    public private(set) var switcher: QuickSwitcher?
    /// The session facts popover on the toolbar's status item is open.
    public private(set) var isShowingSessionFacts = false
    public let conversation: ConversationStore
    public let composer: ComposerStore

    private var herd = Herd()
    private let focus: FocusSync
    private var notes: PaneNotes
    private let notesStore: any PaneNotesStore
    private let clipboard: any Clipboard
    private let opener: any URLOpener
    private let host: String
    @ObservationIgnored private var herdUpdates: AsyncStream<HerdUpdate>?
    private let log = Log(category: "AppModel")

    /// - Parameters:
    ///   - control: changes Herdr on the user's behalf: focus follows the selection, and the composer sends.
    ///   - host: the ssh alias the panes run on, for links that reach them from this Mac.
    public init(
        herdUpdates: AsyncStream<HerdUpdate>,
        transcripts: any TranscriptService,
        control: any HerdrControl,
        notes: any PaneNotesStore = InMemoryPaneNotesStore(),
        clipboard: any Clipboard = InMemoryClipboard(),
        opener: any URLOpener = RecordingURLOpener(),
        host: String = "arch"
    ) {
        self.herdUpdates = herdUpdates
        notesStore = notes
        self.clipboard = clipboard
        self.opener = opener
        self.host = host
        self.notes = notes.load()
        conversation = ConversationStore(transcripts: transcripts)
        composer = ComposerStore(control: control)
        focus = FocusSync(control: control)
    }

    /// Applies herd updates until the stream ends. Call once, for the lifetime of the window.
    public func run() async {
        guard let updates = herdUpdates else { return }
        herdUpdates = nil
        for await update in updates {
            apply(update)
        }
    }

    var focusTask: Task<Void, Never>? { focus.task }

    public func perform(_ command: AppCommand) {
        switch command {
        case .selectPane(let id):
            select(id)
        case .selectNextPane:
            select(neighbour(offset: 1))
        case .selectPreviousPane:
            select(neighbour(offset: -1))
        case .reloadConversation:
            conversation.reload()
        case .send:
            composer.send()
        case .renamePane(let id):
            renaming = id ?? selection
        case .commitRename(let id, let text):
            guard renaming == id else { return }
            renaming = nil
            let label = sections.panes.first { $0.id == id }?.label ?? ""
            updateNotes(notes.renaming(id, to: text, over: label))
        case .cancelRename:
            renaming = nil
        case .togglePin(let id):
            guard let id = id ?? selection else { return }
            updateNotes(notes.togglingPin(id))
        case .toggleSidebar:
            isSidebarVisible.toggle()
        case .setSidebarVisible(let visible):
            isSidebarVisible = visible
        case .biggerText:
            textScale = textScale.bigger
        case .smallerText:
            textScale = textScale.smaller
        case .actualSizeText:
            textScale = .actual
        case .setTextScale(let scale):
            textScale = scale
        case .openQuickSwitcher:
            switcher = QuickSwitcher(items: sections.switcherItems(in: herd))
        case .closeQuickSwitcher:
            switcher = nil
        case .searchQuickSwitcher(let query):
            switcher = switcher?.searching(query)
        case .moveQuickSwitcherHighlight(let offset):
            switcher = switcher?.moving(by: offset)
        case .chooseQuickSwitcherResult(let id):
            guard let chosen = id ?? switcher?.highlighted else { return }
            switcher = nil
            select(chosen)
        case .copyMessage(let id):
            guard let entry = conversation.transcript.entries.first(where: { $0.id == id }) else { return }
            clipboard.copy(Transcript.markdownBody(of: entry))
        case .copyConversation:
            guard !conversation.transcript.entries.isEmpty else { return }
            clipboard.copy(Transcript.markdown(of: conversation.transcript.entries))
        case .expandEntry(let id):
            conversation.expand(id)
        case .collapseEntry(let id):
            conversation.collapse(id)
        case .openInVSCode(let id):
            guard let url = vscodeLink(id) else { return }
            opener.open(url)
        case .toggleSessionFacts:
            isShowingSessionFacts = header != nil && !isShowingSessionFacts
        case .setSessionFactsShown(let shown):
            isShowingSessionFacts = header != nil && shown
        }
    }

    public func isEnabled(_ command: AppCommand) -> Bool {
        switch command {
        case .selectPane, .selectNextPane, .selectPreviousPane: !sections.isEmpty
        case .reloadConversation: conversation.canReload
        case .send: composer.canSend
        case .renamePane(let id): (id ?? selection) != nil
        case .commitRename, .cancelRename: renaming != nil
        case .togglePin(let id): (id ?? selection) != nil
        case .toggleSidebar, .setSidebarVisible, .setTextScale: true
        case .biggerText: !textScale.isLargest
        case .smallerText: !textScale.isSmallest
        case .actualSizeText: textScale != .actual
        case .openQuickSwitcher: !sections.isEmpty && switcher == nil
        case .closeQuickSwitcher, .searchQuickSwitcher, .moveQuickSwitcherHighlight: switcher != nil
        case .chooseQuickSwitcherResult(let id): (id ?? switcher?.highlighted) != nil
        case .copyMessage(let id): conversation.transcript.entries.contains { $0.id == id }
        case .copyConversation: !conversation.transcript.entries.isEmpty
        case .expandEntry, .collapseEntry: true
        case .openInVSCode(let id): vscodeLink(id) != nil
        case .toggleSessionFacts: header != nil
        case .setSessionFactsShown: true
        }
    }

    /// The menu title of `command` as it applies now: Pin becomes Unpin for a pinned pane.
    public func title(of command: AppCommand) -> String {
        switch command {
        case .togglePin(let id) where (id ?? selection).map { notes.pins.contains($0) } == true: "Unpin"
        default: command.title
        }
    }

    private func vscodeLink(_ id: PaneID?) -> URL? {
        (id ?? selection).flatMap { herd.pane($0) }.flatMap { VSCodeLink.url(host: host, pane: $0) }
    }

    func apply(_ update: HerdUpdate) {
        switch update {
        case .herd(let herd):
            let old = self.herd
            let previous = selection.flatMap { old.pane($0) }
            self.herd = herd
            updateNotes(notes.markingFinishedTurns(from: old, to: herd, except: selection))
            refreshSections()
            connection = .connected
            if let selection, herd.pane(selection) == nil {
                log.info("selected pane \(selection) is gone")
            }
            if let renaming, herd.pane(renaming) == nil {
                self.renaming = nil
            }
            refreshSelection()
            // A turn starting or ending changes the log; re-read it so the conversation keeps up.
            if let previous, let current = selection.flatMap({ herd.pane($0) }),
                previous.sessionID == current.sessionID, previous.agentStatus != current.agentStatus
            {
                conversation.reload()
            }
        case .failed(let reason):
            connection = sections.isEmpty ? .offline(reason) : .stale(reason)
            refreshComposer()
        }
    }

    /// The sidebar pipeline: Herdr's structure, then each local feature in turn.
    private func refreshSections() {
        sections = SidebarSection.sections(for: herd)
            .named(notes.names)
            .unread(notes.unread)
            .pinned(notes.pins)
        switcher = switcher?.refreshing(sections.switcherItems(in: herd))
    }

    private func updateNotes(_ notes: PaneNotes) {
        guard notes != self.notes else { return }
        self.notes = notes
        notesStore.save(notes)
        refreshSections()
        header = selection.flatMap { herd.pane($0) }.map(header(for:))
    }

    private func select(_ id: PaneID?) {
        guard id != selection else { return }
        selection = id
        updateNotes(notes.reading(id))
        refreshSelection()
        focus.follow(id)
    }

    private func refreshSelection() {
        let pane = selection.flatMap { herd.pane($0) }
        header = pane.map(header(for:))
        if header == nil {
            isShowingSessionFacts = false
        }
        conversation.show(pane)
        refreshComposer()
    }

    private func refreshComposer() {
        composer.show(selection.flatMap { herd.pane($0) }, isOnline: connection == .connected)
    }

    private func header(for pane: Herd.Pane) -> PaneHeader {
        PaneHeader(
            title: PaneRow.label(for: pane, tab: herd.tab(pane.tabID)),
            location: herd.location(of: pane),
            agent: pane.agent?.title ?? "Shell",
            status: pane.agentStatus
        )
        .named(notes.names, id: pane.id)
    }

    /// The pane `offset` rows away from the selection in sidebar order, wrapping; the first pane when none is selected.
    private func neighbour(offset: Int) -> PaneID? {
        let order = sections.panes.map(\.id)
        guard !order.isEmpty else { return nil }
        guard let selection, let index = order.firstIndex(of: selection) else {
            return offset >= 0 ? order.first : order.last
        }
        return order[(index + offset + order.count) % order.count]
    }
}
