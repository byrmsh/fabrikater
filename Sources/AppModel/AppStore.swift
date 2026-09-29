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
    /// The panes waiting on the user, above the workspaces and on the Dock badge.
    public private(set) var needsYou = NeedsYou()
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
    /// The main window's conversation, composer, prompt card, terminal and panels; each pane window has its own
    /// (`paneWindow(_:)`).
    public let detail: PaneDetailStores
    /// The Settings window's values, which notifications, the composer and text sizes follow.
    public let preferences: PreferencesStore
    /// Builds a window's pane detail stores, all sharing one set of drafts.
    private let makeDetail: () -> PaneDetailStores
    /// The Past Sessions sheet (M8).
    public let pastSessions: PastSessionsStore
    /// Builds a past session's window store.
    private let makeSessionWindow: (SessionWindowID) -> SessionWindowStore

    private var herd = Herd()
    private var activity = PaneActivity()
    private let now: @Sendable () -> Date
    private let focus: FocusSync
    private var notes: PaneNotes
    private let notesStore: any PaneNotesStore
    @ObservationIgnored private var paneWindows = WindowList<PaneWindowStore>()
    @ObservationIgnored private var sessionWindows = WindowList<SessionWindowStore>()
    private let opener: any URLOpener
    private let notifier: any Notifier
    private let isAppActive: @MainActor () -> Bool
    private let host: String
    @ObservationIgnored private var herdUpdates: AsyncStream<HerdUpdate>?
    /// Applies `herdUpdates` while `run()` waits on it.
    @ObservationIgnored private(set) var updatesTask: Task<Void, Never>?
    /// Set by `close()`: the host is let go of, and nothing more is read from it.
    public private(set) var isClosed = false
    private let log = Log(category: "AppModel")

    /// - Parameters:
    ///   - control: changes Herdr on the user's behalf: focus follows the selection, and the composer sends.
    ///   - screens: reads a blocked pane's screen for its prompt card.
    ///   - answers: sends a prompt card's answers; `control` when nil. Not the composer's `SendGuard`, which refuses them.
    ///   - terminals: reads panes' recent output for the terminal views.
    ///   - host: the ssh alias the panes run on, for links that reach them from this Mac.
    ///   - now: the clock that stamps each pane's last activity.
    ///   - notifier: shows an alert when a pane becomes blocked or finishes a turn.
    ///   - isAppActive: whether the app is frontmost, when the selected pane needs no alert.
    ///   - preferences: the Settings window's values.
    ///   - reconnect: the terminal views' backoff while reads fail, cut short when the host is probably back.
    public init(
        herdUpdates: AsyncStream<HerdUpdate>,
        transcripts: any TranscriptService,
        history: any SessionHistory = NoSessionHistory(),
        control: any HerdrControl,
        screens: any PaneReader = UnreadableScreens(),
        answers: (any HerdrControl)? = nil,
        terminals: any TerminalReader = BlankTerminalReader(),
        notes: any PaneNotesStore = InMemoryPaneNotesStore(),
        drafts: any DraftStorage = InMemoryDraftStorage(),
        clipboard: any Clipboard = InMemoryClipboard(),
        opener: any URLOpener = RecordingURLOpener(),
        host: String = "arch",
        now: @escaping @Sendable () -> Date = { Date() },
        notifier: any Notifier = RecordingNotifier(),
        isAppActive: @escaping @MainActor () -> Bool = { true },
        preferences: PreferencesStore = PreferencesStore(),
        reconnect: ReconnectPolicy = ReconnectPolicy()
    ) {
        self.preferences = preferences
        self.herdUpdates = herdUpdates
        notesStore = notes
        self.opener = opener
        self.host = host
        self.now = now
        self.notifier = notifier
        self.isAppActive = isAppActive
        self.notes = notes.load()
        let drafts = Drafts(storage: drafts)
        let answers = answers ?? control
        makeDetail = {
            PaneDetailStores(
                conversation: ConversationStore(transcripts: transcripts),
                composer: ComposerStore(control: control, drafts: drafts),
                prompt: PromptCardStore(reader: screens, control: answers),
                terminal: TerminalStore(reader: terminals, backoff: reconnect.backoff(), pause: reconnect.pause),
                clipboard: clipboard)
        }
        detail = makeDetail()
        focus = FocusSync(control: control)
        pastSessions = PastSessionsStore(history: history, now: now)
        makeSessionWindow = { SessionWindowStore($0, transcripts: transcripts, clipboard: clipboard) }
    }

    /// Applies herd updates until the stream ends, `close()` is called or the caller is cancelled. Call once, for the
    /// lifetime of the window.
    public func run() async {
        guard let updates = herdUpdates else { return }
        herdUpdates = nil
        let task = Task {
            for await update in updates {
                apply(update)
            }
        }
        updatesTask = task
        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }

    /// Lets go of the host for good: stops the herd updates, every read and follow, and closes the pane and past
    /// session windows, whose panes and logs are on this host. A send already on its way finishes.
    public func close() {
        guard !isClosed else { return }
        isClosed = true
        // A feed never run stops once its stream is let go of.
        herdUpdates = nil
        updatesTask?.cancel()
        focus.stop()
        detail.close()
        pastSessions.close()
        for window in paneWindows.stores { window.close() }
        for window in sessionWindows.stores { window.close() }
        log.info("closed the connection to the host")
    }

    var focusTask: Task<Void, Never>? { focus.task }

    public func perform(_ command: AppCommand) {
        if PaneDetailStores.handles(command) {
            detail.perform(command, hasPane: header != nil)
            return
        }
        switch command {
        case .selectPane(let id):
            select(id)
        case .selectNextPane:
            select(neighbour(offset: 1))
        case .selectPreviousPane:
            select(neighbour(offset: -1))
        case .selectNeedsYou(let number):
            guard let pane = needsYou.pane(number: number) else { return }
            select(pane.id)
        case .toggleNotifications(let id):
            guard let id = workspace(id) else { return }
            updateNotes(notes.togglingMuted(id))
        case .renamePane(let id):
            renaming = target(id)
        case .commitRename(let id, let text):
            guard renaming == id else { return }
            renaming = nil
            let label = sections.panes.first { $0.id == id }?.label ?? ""
            updateNotes(notes.renaming(id, to: text, over: label))
        case .cancelRename:
            renaming = nil
        case .togglePin(let id):
            guard let id = target(id) else { return }
            updateNotes(notes.togglingPin(id))
        case .toggleHidden(let id):
            guard let id = target(id) else { return }
            updateNotes(notes.togglingHidden(id))
        case .toggleHiddenWorkspace(let id):
            guard let id = workspace(id) else { return }
            updateNotes(notes.togglingHiddenWorkspace(id))
        case .toggleShowHidden:
            changeNotes { $0.hiding.showHidden.toggle() }
        case .toggleShowShells:
            changeNotes { $0.hiding.showShells.toggle() }
        case .sortPanes(let order):
            changeNotes { $0.order = order }
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
        case .openInVSCode(let id):
            guard let url = vscodeLink(id) else { return }
            opener.open(url)
        case .showPastSessions(let id):
            guard let pane = pane(id) else { return }
            pastSessions.open(pane)
        case .closePastSessions, .openPastSession:
            // SwiftUI's openWindow opens the session's window before this; the window asks `sessionWindow(_:)`.
            pastSessions.close()
        case .openInNewWindow:
            // The view opens the window (SwiftUI's openWindow) with `windowPane(_:)`; the window asks `paneWindow(_:)`.
            break
        default:
            break
        }
    }

    public func isEnabled(_ command: AppCommand) -> Bool {
        if PaneDetailStores.handles(command) {
            return detail.isEnabled(command, hasPane: header != nil) ?? false
        }
        return switch command {
        case .selectPane, .selectNextPane, .selectPreviousPane: !sections.isEmpty
        case .selectNeedsYou(let number): needsYou.pane(number: number) != nil
        case .toggleNotifications(let id): workspace(id) != nil
        case .renamePane(let id), .togglePin(let id), .toggleHidden(let id): target(id) != nil
        case .commitRename, .cancelRename: renaming != nil
        case .toggleHiddenWorkspace(let id): workspace(id) != nil
        case .toggleShowHidden, .toggleShowShells, .sortPanes: true
        case .toggleSidebar, .setSidebarVisible, .setTextScale: true
        case .biggerText: !textScale.isLargest
        case .smallerText: !textScale.isSmallest
        case .actualSizeText: textScale != .actual
        case .openQuickSwitcher: !sections.isEmpty && switcher == nil
        case .closeQuickSwitcher, .searchQuickSwitcher, .moveQuickSwitcherHighlight: switcher != nil
        case .chooseQuickSwitcherResult(let id): (id ?? switcher?.highlighted) != nil
        case .openInVSCode(let id): vscodeLink(id) != nil
        case .openInNewWindow(let id): windowPane(id) != nil
        case .showPastSessions(let id): PastSessionsStore.canList(pane(id))
        case .closePastSessions: pastSessions.sheet != nil
        case .openPastSession(let id): pastSessions.sheet?.rows.contains { $0.window == id } == true
        default: false
        }
    }

    /// The menu title of `command` as it applies now: Pin becomes Unpin for a pinned pane.
    public func title(of command: AppCommand) -> String {
        switch command {
        case .selectNeedsYou(let number): needsYou.pane(number: number)?.label ?? command.title
        case .toggleNotifications(let id) where workspace(id).map { notes.mutedWorkspaces.contains($0) } == true:
            "Turn On Notifications"
        case .togglePin(let id) where target(id).map { notes.pins.contains($0) } == true: "Unpin"
        case .toggleHidden(let id) where target(id).map { notes.hiding.panes.contains($0) } == true:
            "Unhide Pane"
        case .toggleHiddenWorkspace(let id) where workspace(id).map { notes.hiding.workspaces.contains($0) } == true:
            "Unhide Workspace"
        default: command.title
        }
    }

    /// Whether a menu item that switches a setting shows a checkmark; nil for commands that are not settings.
    public func isChecked(_ command: AppCommand) -> Bool? {
        switch command {
        case .toggleShowHidden: notes.hiding.showHidden
        case .toggleShowShells: notes.hiding.showShells
        case .toggleChanges, .toggleTerminal: detail.isChecked(command)
        case .sortPanes(let order): notes.order == order
        default: nil
        }
    }

    /// What the sidebar says when it has no rows: the connection's state, or that everything in the herd is hidden.
    public var emptySidebar: EmptySidebar {
        guard connection == .connected, !herd.panes.isEmpty else { return connection.emptySidebar }
        return EmptySidebar(
            title: "Everything Is Hidden", detail: "Show Hidden Panes and Show Shell Panes are in the View menu.")
    }

    /// The pane `id` (nil: the selection) if Herdr has it, to open in its own window.
    public func windowPane(_ id: PaneID?) -> PaneID? {
        pane(id)?.id
    }

    /// A new pane window's store, with its own conversation, kept up to date with the herd until the window lets go of it.
    public func paneWindow(_ id: PaneID) -> PaneWindowStore {
        let window = PaneWindowStore(paneID: id, detail: makeDetail())
        paneWindows.add(window)
        refresh(window)
        return window
    }

    /// A past session's window store, with its own read-only conversation.
    public func sessionWindow(_ id: SessionWindowID) -> SessionWindowStore {
        let window = makeSessionWindow(id)
        sessionWindows.add(window)
        return window
    }

    private func refreshPaneWindows() {
        paneWindows.stores.forEach(refresh)
    }

    private func refresh(_ window: PaneWindowStore) {
        // Before the first herd a restored window waits rather than saying its pane is gone.
        guard connection != .connecting else { return }
        window.show(herd.pane(window.paneID).map { ($0, header(for: $0)) }, isOnline: connection == .connected)
    }

    private func vscodeLink(_ id: PaneID?) -> URL? {
        pane(id).flatMap { VSCodeLink.url(host: host, pane: $0) }
    }

    func apply(_ update: HerdUpdate) {
        switch update {
        case .herd(let herd):
            let old = self.herd
            self.herd = herd
            activity = activity.seeing(herd, at: now())
            updateNotes(notes.markingFinishedTurns(from: old, to: herd, except: selection))
            refreshSections()
            notify(since: old)
            connection = .connected
            if let selection, herd.pane(selection) == nil {
                log.info("selected pane \(selection) is gone")
            }
            if let renaming, herd.pane(renaming) == nil {
                self.renaming = nil
            }
            refreshSelection()
            refreshPaneWindows()
        case .failed(let reason):
            connection = sections.isEmpty ? .offline(reason) : .stale(reason)
            refreshInput()
            for window in paneWindows.stores {
                window.detail.showInput(herd.pane(window.paneID), isOnline: false)
            }
        }
    }

    /// The sidebar pipeline: Herdr's structure, then each local feature in turn. A herd that changes nothing the sidebar
    /// shows leaves it alone, so an idle poll redraws nothing.
    private func refreshSections() {
        let sections = SidebarSection.sections(for: herd)
            .named(notes.names)
            .active(activity.times)
            .unread(notes.unread)
            .hiding(notes.hiding)
            .sorted(notes.order)
            .pinned(notes.pins)
        if sections != self.sections {
            self.sections = sections
            needsYou = sections.needingYou
        }
        switcher = switcher?.refreshing(sections.switcherItems(in: herd))
    }

    private func notify(since old: Herd) {
        let watched = isAppActive() ? selection : nil
        let chosen = preferences.preferences
        for pane in herd.alerting(since: old, watched: watched, muted: notes.mutedWorkspaces)
        where chosen.notifies(pane.agentStatus) {
            let header = header(for: pane)
            notifier.post(
                PaneAlert(
                    paneID: pane.id, title: header.title, subtitle: header.location, body: pane.agentStatus.alertBody,
                    playsSound: chosen.playsSound))
        }
    }

    private func updateNotes(_ notes: PaneNotes) {
        guard notes != self.notes else { return }
        self.notes = notes
        notesStore.save(notes)
        refreshSections()
        header = pane(nil).map(header(for:))
        refreshPaneWindows()
    }

    private func changeNotes(_ change: (inout PaneNotes) -> Void) {
        var notes = notes
        change(&notes)
        updateNotes(notes)
    }

    private func select(_ id: PaneID?) {
        guard id != selection else { return }
        selection = id
        updateNotes(notes.reading(id))
        refreshSelection()
        focus.follow(id)
    }

    private func refreshSelection() {
        let selected = pane(nil)
        header = selected.map(header(for:))
        detail.show(selected)
        refreshInput()
    }

    private func refreshInput() {
        detail.showInput(pane(nil), isOnline: connection == .connected)
    }

    private func header(for pane: Herd.Pane) -> PaneHeader {
        PaneHeader(
            title: PaneRow.label(for: pane, tab: herd.tab(pane.tabID)),
            location: herd.location(of: pane),
            agent: pane.agent.title,
            status: pane.agentStatus
        )
        .named(notes.names, id: pane.id)
    }

    /// The pane a command names, or the selection when it names none.
    private func target(_ id: PaneID?) -> PaneID? {
        id ?? selection
    }

    /// The pane `id` (nil: the selection) as Herdr has it.
    private func pane(_ id: PaneID?) -> Herd.Pane? {
        target(id).flatMap { herd.pane($0) }
    }

    /// The workspace `id` if Herdr has it; for nil, the selected pane's workspace.
    private func workspace(_ id: String?) -> String? {
        guard let id else { return pane(nil)?.workspaceID }
        return herd.workspace(id)?.id
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
