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
    public private(set) var transcript = Transcript()
    public private(set) var isLoading = false
    /// Why there is no conversation, or why the last load failed (the transcript shown is then stale).
    public private(set) var message: String?
    /// Which long entries the user expanded; reset when another pane is shown.
    public private(set) var expansion = EntryExpansion()
    /// How much of the log the conversation reads; grows with Load Earlier Messages, reset when another pane is shown.
    public private(set) var window = TranscriptWindow.full

    private let transcripts: any TranscriptService
    private let log = Log(category: "AppModel")
    private var sessionLog: SessionLog?
    private var status: AgentStatus?
    private var cache = TranscriptCache()
    @ObservationIgnored private(set) var loadTask: Task<Void, Never>?
    /// True while the log is followed live, which already shows what a status change would re-read.
    @ObservationIgnored private var isFollowing = false

    /// The session facts popover's rows (B11).
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
                for try await transcript in transcripts.followTranscript(of: sessionLog, bytes: window) {
                    guard !Task.isCancelled, self.paneID == paneID, self.sessionLog == sessionLog else { return }
                    self.transcript = transcript
                    cache.store(transcript, for: sessionLog)
                    message = nil
                    isLoading = false
                    isFollowing = true
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
