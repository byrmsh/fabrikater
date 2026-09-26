import FabrikaterCore
import HerdrKit
import Observation
import TranscriptKit

/// The selected pane's conversation, read from its session log.
///
/// A pane seen recently shows its cached conversation at once and re-reads in the background. A pane seen for the
/// first time reads a small window first, so something shows quickly, then the full window.
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

    private let transcripts: any TranscriptService
    private let log = Log(category: "AppModel")
    private var session: SessionID?
    private var cache = TranscriptCache()
    @ObservationIgnored private(set) var loadTask: Task<Void, Never>?

    /// False when the pane has no conversation this version can read.
    public var canReload: Bool { session != nil }

    public init(transcripts: any TranscriptService) {
        self.transcripts = transcripts
    }

    /// Shows `pane`'s conversation. Loads when the pane or its session changed, and otherwise does nothing.
    func show(_ pane: Herd.Pane?) {
        let session = pane?.sessionID
        guard pane?.id != paneID || session != self.session else { return }
        loadTask?.cancel()
        paneID = pane?.id
        self.session = session
        let cached = session.flatMap { cache[$0] }
        transcript = cached ?? Transcript()
        expansion = EntryExpansion()
        isLoading = false
        message = Self.unavailableReason(for: pane)
        if message == nil {
            load(quickFirst: cached == nil)
        }
    }

    /// Re-reads the log, keeping the current transcript on screen until the new one arrives.
    func reload() {
        load(quickFirst: false)
    }

    func expand(_ id: String) {
        expansion = expansion.expanding(id)
    }

    func collapse(_ id: String) {
        expansion = expansion.collapsing(id)
    }

    private func load(quickFirst: Bool) {
        guard let paneID, let session else { return }
        loadTask?.cancel()
        isLoading = true
        loadTask = Task {
            do {
                if quickFirst {
                    let quick = try await transcripts.claudeTranscript(session: session, bytes: TranscriptWindow.quick)
                    guard !Task.isCancelled, self.paneID == paneID else { return }
                    transcript = quick
                    message = nil
                    if !quick.isClipped {
                        cache.store(quick, for: session)
                        isLoading = false
                        return
                    }
                }
                let transcript = try await transcripts.claudeTranscript(session: session, bytes: TranscriptWindow.full)
                guard !Task.isCancelled, self.paneID == paneID else { return }
                self.transcript = transcript
                cache.store(transcript, for: session)
                message = nil
                log.debug("loaded \(transcript.entries.count) entries for \(paneID)")
            } catch {
                guard !Task.isCancelled, self.paneID == paneID else { return }
                message = String(describing: error)
                log.error("transcript load failed for \(paneID)")
            }
            isLoading = false
        }
    }

    /// Nil when the pane has a conversation this version can read.
    static func unavailableReason(for pane: Herd.Pane?) -> String? {
        guard let pane else { return nil }
        guard let agent = pane.agent else {
            return "This pane runs a shell, not an agent."
        }
        guard agent == .claude else {
            // TODO(M7): parsers for the other agents.
            return "Conversations from \(agent.title) cannot be shown yet."
        }
        guard pane.sessionID != nil else {
            return "Herdr has not reported a session for this pane yet."
        }
        return nil
    }
}
