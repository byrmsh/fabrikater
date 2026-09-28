import FabrikaterCore
import Foundation
import HerdrKit
import Observation
import PromptKit

/// What the card above the composer shows while Herdr reports the pane `blocked` (docs/design.md, "Blocked panes").
public enum PromptCard: Equatable, Sendable {
    /// A prompt read off the pane's screen, answered with its options' keys.
    case prompt(Prompt)
    /// The agent waits for something this app cannot read, so it offers no answer.
    case unknown
}

/// One of the card's answers, as its button and the Pane menu show it.
public struct PromptOption: Equatable, Sendable, Identifiable {
    /// The key it presses.
    public let number: Int
    public let label: String
    /// The option's explanation under it, when the prompt gives one.
    public let detail: String?

    public var id: Int { number }
    /// The key on the button.
    public var key: String { String(number) }
    /// The menu item's title: "2. No".
    public var title: String { "\(number). \(label)" }
    /// The button's help tag.
    public var help: String { "Press \(number) in the pane: \(label)" }
}

/// Reads the blocked pane's screen into a `PromptCard` and answers it.
///
/// An answer goes only if a fresh read still shows the same prompt, and the host checks the prompt's rows again right
/// before the keys (docs/parsing.md 4.4). It does not go through `SendGuard`, which refuses any key but Esc and
/// Control-C while a dialog shows (decisions/0009). Removing this file, its view and its lines in the two stores
/// removes the feature.
@MainActor
@Observable
public final class PromptCardStore {
    public private(set) var card: PromptCard?
    /// The option being sent, while it is.
    public private(set) var answering: Int?
    /// Why the last answer did not go, or that it went and the prompt stayed.
    public private(set) var notice: String?

    private var paneID: PaneID?
    /// The pane state last read for: a new status or revision may be a new prompt.
    private var seen: Seen?
    private var isOnline = false
    private let reader: any PaneReader
    private let control: any HerdrControl
    private let sleep: @Sendable (Duration) async throws -> Void
    @ObservationIgnored private(set) var task: Task<Void, Never>?

    private struct Seen: Equatable {
        let pane: PaneID
        let revision: Int?
    }

    /// - Parameters:
    ///   - control: sends the answer. Not the composer's `SendGuard`.
    ///   - sleep: waits between the reads that look for the prompt to go after an answer.
    public init(
        reader: any PaneReader, control: any HerdrControl,
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.reader = reader
        self.control = control
        self.sleep = sleep
    }

    /// Whether the card shows: Herdr reports the pane `blocked`.
    public var isShown: Bool { card != nil }

    /// The prompt's question, or what the card says when it has no options to offer.
    public var question: String {
        guard case .prompt(let prompt) = card else { return Self.unknownMessage }
        return prompt.question
    }

    /// What the prompt is about, one row per line: a command, a file, a question's header.
    public var subject: String? {
        guard case .prompt(let prompt) = card, !prompt.subject.isEmpty else { return nil }
        return prompt.subject.joined(separator: "\n")
    }

    public var options: [PromptOption] {
        guard case .prompt(let prompt) = card else { return [] }
        return prompt.options.map { PromptOption(number: $0.number, label: $0.label, detail: $0.description) }
    }

    /// The Pane menu's submenu of options.
    public static let menuTitle = "Answer Prompt"

    /// The card's heading.
    public var title: String {
        guard case .prompt(let prompt) = card else { return "Waiting for Input" }
        return switch prompt.family {
        case .permission: "Permission Needed"
        case .select: "Question"
        case .plan: "Plan Ready"
        case .trust: "Trust This Folder?"
        }
    }

    /// What the card says when it has no options to offer.
    public static let unknownMessage =
        "The agent is waiting for input that fabrikater can't read. Answer it in Herdr, or press Esc to cancel it."

    public var canAnswer: Bool { isOnline && answering == nil }

    /// Follows the selection: reads the screen when the pane turns blocked or changes while blocked.
    func show(_ pane: Herd.Pane?, isOnline: Bool) {
        self.isOnline = isOnline
        guard let pane, pane.agentStatus == .blocked else {
            reset()
            return
        }
        let seen = Seen(pane: pane.id, revision: pane.revision)
        guard seen != self.seen else { return }
        if pane.id != paneID {
            reset()
        }
        paneID = pane.id
        self.seen = seen
        guard pane.agent == .claude else {
            card = .unknown
            return
        }
        // An answer in flight reads the screen itself once it is sent.
        guard answering == nil else { return }
        task = Task { await refresh(pane.id) }
    }

    /// Sends the keys for option `number` of the prompt on the card.
    func answer(_ number: Int) {
        guard canAnswer, let paneID, case .prompt(let prompt) = card,
            let option = prompt.options.first(where: { $0.number == number }),
            let digit = HerdrRequest.Key.digit(number)
        else { return }
        answering = number
        notice = nil
        let keys = prompt.confirmsWithEnter ? [digit, .enter] : [digit]
        task = Task {
            defer { answering = nil }
            let now = await read(paneID)
            guard now == .prompt(prompt) else {
                card = now
                notice = Self.changedNotice
                return
            }
            guard !Task.isCancelled else { return }
            do {
                try await control.perform([.checked(Self.check(prompt), .sendKeys(paneID, keys))])
            } catch let error as HerdrError where error == .screenChanged {
                notice = Self.changedNotice
                await refresh(paneID)
                return
            } catch {
                notice = "Could not send the answer: \(error)"
                return
            }
            for _ in 0..<Self.goneReads {
                try? await sleep(Self.goneInterval)
                guard !Task.isCancelled, self.paneID == paneID else { return }
                let now = await read(paneID)
                if now != .prompt(prompt) {
                    card = now
                    return
                }
            }
            notice = "Sent “\(option.label)”, but the prompt is still showing."
        }
    }

    static let changedNotice =
        "The prompt changed before the answer went, so nothing was sent. Check it and choose again."
    /// Reads looking for the answered prompt to go, and the wait between them: Collie's 8 × 350 ms.
    static let goneReads = 8
    static let goneInterval = Duration.milliseconds(350)

    /// The host sends the keys only while the prompt's rows, question through footer, are still at the bottom.
    static func check(_ prompt: Prompt) -> ScreenCheck {
        ScreenCheck(rows: prompt.region, refusing: [], window: prompt.region.count + 6)
    }

    private func refresh(_ pane: PaneID) async {
        let card = await read(pane)
        guard paneID == pane else { return }
        // Herdr says the agent is blocked, so a screen without a dialog still gets the card that offers no answer.
        self.card = card ?? .unknown
    }

    /// The card the pane's screen shows now: nil once no dialog is up, `.unknown` when one is but it is not a prompt
    /// this app reads, or the screen could not be read.
    private func read(_ pane: PaneID) async -> PromptCard? {
        do {
            let screen = Screen(ansi: try await reader.screen(of: pane))
            if let prompt = Prompt(on: screen) { return .prompt(prompt) }
            return Dialog(on: screen) == nil ? nil : .unknown
        } catch {
            notice = "Could not read the pane's screen: \(error)"
            return .unknown
        }
    }

    private func reset() {
        task?.cancel()
        task = nil
        paneID = nil
        seen = nil
        card = nil
        notice = nil
        answering = nil
    }
}

/// A `PaneReader` for stores built without one: every read fails, so a blocked pane's card offers no answer.
public struct UnreadableScreens: PaneReader {
    public init() {}

    public func screen(of pane: PaneID) async throws -> String {
        throw HerdrError("No screen reader")
    }
}
