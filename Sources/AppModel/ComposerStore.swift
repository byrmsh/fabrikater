import FabrikaterCore
import Foundation
import HerdrKit
import Observation

/// The text field under the conversation: a draft per pane, and sending it to the pane as a prompt.
@MainActor
@Observable
public final class ComposerStore {
    public private(set) var paneID: PaneID?
    /// "Queue" while the agent is working, since the agent queues what it is sent (docs/design.md, "Composer").
    public private(set) var sendTitle = "Send"
    /// Why sending is off, when it is.
    public private(set) var disabledReason: String?
    /// Why the key bar is off, when it is: no pane, or offline. A dialog leaves the keys that cancel it on.
    private var keysDisabledReason: String?

    /// Shared with the other windows' composers and kept between launches.
    private let drafts: Drafts
    /// Per pane, like the drafts, so switching panes mid-send shows each pane's own state.
    private var sending: Set<PaneID> = []
    private var errors: [PaneID: String] = [:]
    private let control: any HerdrControl
    private let log = Log(category: "AppModel")
    @ObservationIgnored private(set) var sendTask: Task<Void, Never>?
    @ObservationIgnored private(set) var keyTask: Task<Void, Never>?

    public init(control: any HerdrControl, drafts: Drafts = Drafts()) {
        self.control = control
        self.drafts = drafts
    }

    /// The selected pane's draft. The view binds its text field to this.
    public var draft: String {
        get { paneID.map { drafts[$0] } ?? "" }
        set {
            guard let paneID else { return }
            drafts[paneID] = newValue
            errors[paneID] = nil
        }
    }

    public var isSending: Bool { paneID.map(sending.contains) ?? false }

    /// Why the selected pane's last send failed; its draft is kept.
    public var error: String? { paneID.flatMap { errors[$0] } }

    /// Set while Herdr reports the selected pane `blocked`: the agent shows a dialog, which typed text would answer.
    public private(set) var waitingNotice: String?

    /// The line above the field: the last send's error, else what the agent is waiting for.
    public var notice: String? { error ?? waitingNotice }

    public var canSend: Bool {
        disabledReason == nil && !isSending && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Follows the selection and the connection.
    func show(_ pane: Herd.Pane?, isOnline: Bool) {
        paneID = pane?.id
        sendTitle = pane?.agentStatus == .working ? "Queue" : "Send"
        waitingNotice = pane?.agentStatus == .blocked ? Self.blockedNotice : nil
        keysDisabledReason = Self.disabledReason(hasPane: pane != nil, isOnline: isOnline)
        disabledReason = keysDisabledReason ?? waitingNotice
    }

    static let blockedNotice = "Sending is off while the agent waits for an answer."

    private static func disabledReason(hasPane: Bool, isOnline: Bool) -> String? {
        guard hasPane else { return "No pane is selected." }
        guard isOnline else { return "Offline: sending waits for the host." }
        return nil
    }

    /// Sends the draft as a prompt. The draft clears only once Herdr took it; on failure it stays with the error.
    func send() {
        guard canSend, let paneID else { return }
        let text = draft
        sending.insert(paneID)
        errors[paneID] = nil
        sendTask = Task {
            do {
                try await control.perform(HerdrRequest.prompt(text, to: paneID))
                // Keep anything typed while the send was in flight.
                let current = drafts[paneID]
                if current.hasPrefix(text) {
                    drafts[paneID] = String(current.dropFirst(text.count))
                }
                log.info("sent a prompt to \(paneID)")
            } catch {
                errors[paneID] = String(describing: error)
                log.error("send to \(paneID) failed")
            }
            sending.remove(paneID)
        }
    }

    /// Whether the key bar's `key` can go to the selected pane. While the agent waits for an answer only Esc and
    /// Control-C can: they back out of the dialog, where the other keys would answer it.
    public func canSend(_ key: PaneKey) -> Bool {
        keysDisabledReason == nil && (waitingNotice == nil || key.key.cancels)
    }

    /// Sends one key to the selected pane. The draft is left alone; a failure shows as the composer's error.
    func send(_ key: PaneKey) {
        guard canSend(key), let paneID else { return }
        errors[paneID] = nil
        keyTask = Task {
            do {
                try await control.perform([.sendKeys(paneID, [key.key])])
                log.info("sent a key to \(paneID)")
            } catch {
                errors[paneID] = String(describing: error)
                log.error("key to \(paneID) failed")
            }
        }
    }
}
