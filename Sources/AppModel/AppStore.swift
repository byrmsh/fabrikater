import FabrikaterCore
import HerdrKit
import Observation
import TranscriptKit

/// Whether the herd on screen is current.
public enum ConnectionState: Equatable, Sendable {
    case connecting
    case connected
    /// The last read failed; the herd shown is the last one that succeeded.
    case stale(String)

    public var title: String {
        switch self {
        case .connecting: "Connecting…"
        case .connected: "Connected"
        case .stale: "Offline, showing the last known state"
        }
    }
}

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
    public let conversation: ConversationStore
    public let composer: ComposerStore

    private var herd = Herd()
    private let focus: FocusSync
    @ObservationIgnored private var herdUpdates: AsyncStream<HerdUpdate>?
    private let log = Log(category: "AppModel")

    /// - Parameter control: changes Herdr on the user's behalf: focus follows the selection, and the composer sends.
    public init(herdUpdates: AsyncStream<HerdUpdate>, transcripts: any TranscriptService, control: any HerdrControl) {
        self.herdUpdates = herdUpdates
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
        }
    }

    public func isEnabled(_ command: AppCommand) -> Bool {
        switch command {
        case .selectPane, .selectNextPane, .selectPreviousPane: !sections.isEmpty
        case .reloadConversation: conversation.canReload
        case .send: composer.canSend
        }
    }

    func apply(_ update: HerdUpdate) {
        switch update {
        case .herd(let herd):
            let previous = selection.flatMap { self.herd.pane($0) }
            self.herd = herd
            sections = SidebarSection.sections(for: herd)
            connection = .connected
            if let selection, herd.pane(selection) == nil {
                log.info("selected pane \(selection) is gone")
            }
            refreshSelection()
            // A turn starting or ending changes the log; re-read it so the conversation keeps up.
            if let previous, let current = selection.flatMap({ herd.pane($0) }),
                previous.sessionID == current.sessionID, previous.agentStatus != current.agentStatus
            {
                conversation.reload()
            }
        case .failed(let reason):
            connection = .stale(reason)
            refreshComposer()
        }
    }

    private func select(_ id: PaneID?) {
        guard id != selection else { return }
        selection = id
        refreshSelection()
        focus.follow(id)
    }

    private func refreshSelection() {
        let pane = selection.flatMap { herd.pane($0) }
        header = pane.map(header(for:))
        conversation.show(pane)
        refreshComposer()
    }

    private func refreshComposer() {
        composer.show(selection.flatMap { herd.pane($0) }, isOnline: connection == .connected)
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
