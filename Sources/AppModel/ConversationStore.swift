import FabrikaterCore
import HerdrKit
import Observation
import TranscriptKit

/// One pane's conversation, read from its session log: the main window's selected pane, or a pane window's pane.
///
/// A pane seen recently shows its cached conversation at once and re-reads in the background. A pane seen for the
/// first time reads a small window first, so something shows quickly, then the full window. After that the log is
/// followed, so new rows appear as the agent writes them.
@MainActor
@Observable
public final class ConversationStore {
    public private(set) var paneID: PaneID?
    public private(set) var transcript = Transcript() {
        didSet { find.refresh(transcript.entries) }
    }
    public private(set) var isLoading = false
    /// Why there is no conversation, or why the last load failed (the transcript shown is then stale).
    public private(set) var message: String?
    /// Which long entries the user expanded; reset when another pane is shown.
    public private(set) var expansion = EntryExpansion()
    /// How much of the log the conversation reads; grows with Load Earlier Messages, reset when another pane is shown.
    public private(set) var window = TranscriptWindow.full
    /// The find bar (⌘F): it stays open, with its query, when another pane is shown.
    public private(set) var find = ConversationFind()

    private let transcripts: any TranscriptService
    private let log = Log(category: "AppModel")
    private var sessionLog: SessionLog?
    private var status: AgentStatus?
    private var cache = TranscriptCache()
    @ObservationIgnored private(set) var loadTask: Task<Void, Never>?
    /// True while the log is followed live, which already shows what a status change would re-read.
    @ObservationIgnored private var isFollowing = false

    /// The Session Info panel's rows (B11).
    public var factRows: [FactRow] { transcript.facts.rows(isClipped: transcript.isClipped) }

    /// False when the pane has no conversation this version can read.
    public var canReload: Bool { sessionLog != nil }

    /// True when older messages exist and a larger window can still show them.
    public var canLoadEarlier: Bool {
        sessionLog != nil && transcript.isClipped && !isLoading && TranscriptWindow.earlier(than: window) != nil
    }

    /// What the top of a clipped conversation says, or nil when the whole log is shown.
    public var earlierNote: String? {
        guard transcript.isClipped else { return nil }
        if isLoading { return "Loading earlier messages…" }
        return canLoadEarlier ? nil : "Earlier messages are too far back to load."
    }

    /// True when the find bar may offer to read further back, so a search covers older messages too.
    public var canFindEarlier: Bool { find.status != nil && canLoadEarlier }

    /// True when `entry` shows only its first lines: collapsed, and not a find match, whose highlights must show.
    public func isCollapsed(_ entry: TranscriptEntry) -> Bool {
        expansion.isCollapsed(entry) && !find.reveals(entry)
    }

    /// The entry's Show All or Show Less, or nil when it is too short to collapse or a find match shows it whole.
    public func toggle(for entry: TranscriptEntry) -> AppCommand? {
        find.reveals(entry) ? nil : expansion.toggle(for: entry)
    }

    public init(transcripts: any TranscriptService) {
        self.transcripts = transcripts
    }

    /// Shows `pane`'s conversation. Loads when the pane or its session changed, then follows the log as it grows. When
    /// the log is not followed (the follow ended or failed), a status change re-reads it, since a turn starting or
    /// ending changes the log.
    func show(_ pane: Herd.Pane?) {
        let sessionLog = pane?.sessionLog
        let previousStatus = status
        status = pane?.agentStatus
        guard pane?.id != paneID || sessionLog != self.sessionLog else {
            if previousStatus != status, !isFollowing, Self.unavailableReason(for: pane) == nil { reload() }
            return
        }
        start(pane?.id, sessionLog, unavailable: Self.unavailableReason(for: pane))
    }

    /// Shows a session's conversation by its log alone, with no pane behind it: a past session's window (M8).
    func show(_ log: SessionLog) {
        guard log != sessionLog else { return }
        start(nil, log, unavailable: nil)
    }

    /// Stops reading and following the log, for good: the window or the host it read from is gone.
    func close() {
        loadTask?.cancel()
        loadTask = nil
        isLoading = false
        isFollowing = false
    }

    private func start(_ paneID: PaneID?, _ sessionLog: SessionLog?, unavailable: String?) {
        loadTask?.cancel()
        self.paneID = paneID
        self.sessionLog = sessionLog
        let cached = sessionLog.flatMap { cache[$0] }
        transcript = cached ?? Transcript()
        expansion = EntryExpansion()
        window = TranscriptWindow.full
        isLoading = false
        message = unavailable
        if message == nil {
            load(quickFirst: cached == nil)
        }
    }

    /// Re-reads the log, keeping the current transcript on screen until the new one arrives.
    func reload() {
        load(quickFirst: false)
    }

    /// Handles the commands that act on this conversation alone; ignores every other.
    func perform(_ command: AppCommand, clipboard: any Clipboard) {
        switch command {
        case .reloadConversation:
            reload()
        case .loadEarlier:
            guard canLoadEarlier, let earlier = TranscriptWindow.earlier(than: window) else { return }
            window = earlier
            reload()
        case .copyMessage(let id):
            guard let entry = transcript.entries.first(where: { $0.id == id }) else { return }
            clipboard.copy(Transcript.markdownBody(of: entry))
        case .copyConversation:
            guard !transcript.entries.isEmpty else { return }
            clipboard.copy(Transcript.markdown(of: transcript.entries))
        case .findInConversation:
            find.show()
        case .searchConversation(let query):
            find.search(query, in: transcript.entries)
        case .findNext:
            find.step(1)
        case .findPrevious:
            find.step(-1)
        case .closeFind:
            find.hide()
        case .expandEntry(let id):
            expansion = expansion.expanding(id)
        case .collapseEntry(let id):
            expansion = expansion.collapsing(id)
        default:
            break
        }
    }

    /// Whether a conversation command applies now; nil for any other command.
    func isEnabled(_ command: AppCommand) -> Bool? {
        switch command {
        case .reloadConversation: canReload
        case .loadEarlier: canLoadEarlier
        case .copyMessage(let id): transcript.entries.contains { $0.id == id }
        case .copyConversation: !transcript.entries.isEmpty
        case .expandEntry, .collapseEntry: true
        case .findInConversation: !transcript.entries.isEmpty
        case .searchConversation, .closeFind: find.isShown
        case .findNext, .findPrevious: !find.matches.isEmpty
        default: nil
        }
    }

    private func load(quickFirst: Bool) {
        guard let sessionLog else { return }
        let paneID = paneID
        loadTask?.cancel()
        isLoading = true
        isFollowing = false
        let window = window
        loadTask = Task {
            do {
                if quickFirst {
                    let quick = try await transcripts.transcript(of: sessionLog, bytes: TranscriptWindow.quick)
                    guard !Task.isCancelled, self.paneID == paneID, self.sessionLog == sessionLog else { return }
                    transcript = quick
                    message = nil
                    isLoading = quick.isClipped
                }
                for try await update in transcripts.followTranscript(of: sessionLog, bytes: window) {
                    guard !Task.isCancelled, self.paneID == paneID, self.sessionLog == sessionLog else { return }
                    switch update {
                    case .transcript(let transcript):
                        self.transcript = transcript
                        cache.store(transcript, for: sessionLog)
                        message = nil
                        isLoading = false
                        isFollowing = true
                    case .interrupted(let reason):
                        message = Self.interruptedMessage(reason)
                        isFollowing = false
                    }
                }
            } catch {
                guard !Task.isCancelled, self.paneID == paneID, self.sessionLog == sessionLog else { return }
                message = String(describing: error)
                log.error("transcript load failed for \(sessionLog)")
            }
            guard !Task.isCancelled else { return }
            isLoading = false
            isFollowing = false
        }
    }

    /// What shows above a conversation whose live follow dropped, until the follow reconnects.
    static func interruptedMessage(_ reason: String) -> String {
        "Live updates stopped: \(reason). Reconnecting…"
    }

    /// True when the pane runs an agent whose log this version can read; the detail shows the terminal otherwise.
    static func hasParser(_ pane: Herd.Pane?) -> Bool {
        pane?.agent.flatMap(SessionLog.Format.init(agent:)) != nil
    }

    /// Nil when the pane has a conversation this version can read.
    static func unavailableReason(for pane: Herd.Pane?) -> String? {
        guard let pane else { return nil }
        guard let agent = pane.agent else {
            return "This pane runs a shell, not an agent."
        }
        guard hasParser(pane) else {
            return "Conversations from \(agent.title) cannot be shown yet."
        }
        guard pane.sessionID != nil else {
            return "Herdr has not reported a session for this pane yet."
        }
        return nil
    }
}
