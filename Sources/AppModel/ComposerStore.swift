import FabrikaterCore
import Foundation
import HerdrKit
import Observation

/// The text field under the conversation: a draft per pane, and sending it to the pane as a prompt.
@MainActor
@Observable
public final class ComposerStore {
    public private(set) var paneID: PaneID?
    public private(set) var isSending = false
    /// Why the last send failed; the draft is kept.
    public private(set) var error: String?
    /// "Queue" while the agent is working, since the agent queues what it is sent (docs/design.md, "Composer").
    public private(set) var sendTitle = "Send"
    /// Why sending is off, when it is.
    public private(set) var disabledReason: String?

    private var drafts: [PaneID: String] = [:]
    private let control: any HerdrControl
    private let log = Log(category: "AppModel")
    @ObservationIgnored private(set) var sendTask: Task<Void, Never>?

    public init(control: any HerdrControl) {
        self.control = control
    }

    /// The selected pane's draft. The view binds its text field to this.
    public var draft: String {
        get { paneID.flatMap { drafts[$0] } ?? "" }
        set {
            guard let paneID else { return }
            drafts[paneID] = newValue
            error = nil
        }
    }

    public var placeholder: String {
        "Message the agent. Return sends, Option-Return adds a line."
    }

    public var canSend: Bool {
        disabledReason == nil && !isSending && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Follows the selection and the connection.
    func show(_ pane: Herd.Pane?, isOnline: Bool) {
        if pane?.id != paneID {
            paneID = pane?.id
            error = nil
        }
        sendTitle = pane?.agentStatus == .working ? "Queue" : "Send"
        disabledReason = Self.disabledReason(hasPane: pane != nil, isOnline: isOnline)
    }

    private static func disabledReason(hasPane: Bool, isOnline: Bool) -> String? {
        guard hasPane else { return "No pane is selected." }
        guard isOnline else { return "Offline: sending waits for the host." }
        return nil
    }

    /// Sends the draft as a prompt. The draft clears only once Herdr took it; on failure it stays with the error.
    func send() {
        guard canSend, let paneID else { return }
        let text = draft
        isSending = true
        error = nil
        sendTask = Task {
            do {
                try await control.perform(HerdrRequest.prompt(text, to: paneID))
                if drafts[paneID] == text {
                    drafts[paneID] = nil
                }
                log.info("sent a prompt to \(paneID)")
            } catch {
                if self.paneID == paneID {
                    self.error = String(describing: error)
                }
                log.error("send to \(paneID) failed")
            }
            isSending = false
        }
    }
}
