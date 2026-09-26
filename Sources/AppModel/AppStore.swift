import FabrikaterCore
import HerdrKit
import Observation
import TranscriptKit

/// The header above the selected pane's conversation.
public struct PaneHeader: Equatable, Sendable {
    public var title: String
    /// "Workspace › Tab".
    public var location: String
    public var agent: String
    public var status: AgentStatus
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
    public let conversation: ConversationStore

    private var herd = Herd()
    private var notes: PaneNotes
    private let notesStore: any PaneNotesStore
    @ObservationIgnored private var herdUpdates: AsyncStream<HerdUpdate>?
    private let log = Log(category: "AppModel")

    public init(
        herdUpdates: AsyncStream<HerdUpdate>,
        transcripts: any TranscriptService,
        notes: any PaneNotesStore = InMemoryPaneNotesStore()
    ) {
        self.herdUpdates = herdUpdates
        notesStore = notes
        self.notes = notes.load()
        conversation = ConversationStore(transcripts: transcripts)
    }

    /// Applies herd updates until the stream ends. Call once, for the lifetime of the window.
    public func run() async {
        guard let updates = herdUpdates else { return }
        herdUpdates = nil
        for await update in updates {
            apply(update)
        }
    }

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
        case .renamePane(let id):
            renaming = id ?? selection
        case .commitRename(let id, let text):
            guard renaming == id else { return }
            renaming = nil
            let label = sections.flatMap { $0.rows.flatMap(\.panes) }.first { $0.id == id }?.label ?? ""
            updateNotes(notes.renaming(id, to: text, over: label))
        case .cancelRename:
            renaming = nil
        }
    }

    public func isEnabled(_ command: AppCommand) -> Bool {
        switch command {
        case .selectPane, .selectNextPane, .selectPreviousPane: !sections.isEmpty
        case .reloadConversation: conversation.canReload
        case .renamePane(let id): (id ?? selection) != nil
        case .commitRename, .cancelRename: renaming != nil
        }
    }

    func apply(_ update: HerdUpdate) {
        switch update {
        case .herd(let herd):
            let previous = selection.flatMap { self.herd.pane($0) }
            self.herd = herd
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
        }
    }

    /// The sidebar pipeline: Herdr's structure, then each local feature in turn.
    private func refreshSections() {
        sections = SidebarSection.sections(for: herd)
            .named(notes.names)
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
        refreshSelection()
    }

    private func refreshSelection() {
        let pane = selection.flatMap { herd.pane($0) }
        header = pane.map(header(for:))
        conversation.show(pane)
    }

    private func header(for pane: Herd.Pane) -> PaneHeader {
        let tab = herd.tab(pane.tabID)
        let location = [herd.workspace(pane.workspaceID)?.label, tab?.label]
            .compactMap { $0?.isEmpty == false ? $0 : nil }
            .joined(separator: " › ")
        return PaneHeader(
            title: PaneRow.label(for: pane, tab: tab),
            location: location,
            agent: pane.agent?.title ?? "Shell",
            status: pane.agentStatus
        )
        .named(notes.names, id: pane.id)
    }

    /// The pane `offset` rows away from the selection in sidebar order, wrapping; the first pane when none is selected.
    private func neighbour(offset: Int) -> PaneID? {
        let order = sections.flatMap { $0.rows.flatMap(\.panes) }.map(\.id)
        guard !order.isEmpty else { return nil }
        guard let selection, let index = order.firstIndex(of: selection) else {
            return offset >= 0 ? order.first : order.last
        }
        return order[(index + offset + order.count) % order.count]
    }
}
