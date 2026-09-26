import FabrikaterCore
import HerdrKit
import Observation
import TranscriptKit

/// The selected pane's conversation, read from its session log.
@MainActor
@Observable
public final class ConversationStore {
    public private(set) var paneID: PaneID?
    public private(set) var transcript = Transcript()
    public private(set) var isLoading = false
    /// Why there is no conversation, or why the last load failed (the transcript shown is then stale).
    public private(set) var message: String?

    private let transcripts: any TranscriptService
    private let log = Log(category: "AppModel")
    private var session: SessionID?
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
        transcript = Transcript()
        isLoading = false
        message = Self.unavailableReason(for: pane)
        if message == nil {
            reload()
        }
    }

    /// Re-reads the log, keeping the current transcript on screen until the new one arrives.
    func reload() {
        guard let paneID, let session else { return }
        loadTask?.cancel()
        isLoading = true
        loadTask = Task {
            do {
                let transcript = try await transcripts.claudeTranscript(session: session)
                guard !Task.isCancelled, self.paneID == paneID else { return }
                self.transcript = transcript
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
