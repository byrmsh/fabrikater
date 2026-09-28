import FabrikaterCore
import Foundation
import HerdrKit
import PromptKit

/// A `HerdrControl` that reads the pane's screen before each request that types into it, and refuses while the agent
/// shows a dialog there: typed text would answer the dialog instead of reaching the agent (docs/parsing.md 4.4).
///
/// Each request also carries a `ScreenCheck` the host runs right before sending it, so a dialog that appears after the
/// app looked still cannot take the keys. When the screen shows Claude Code's input box, a prompt (its text, then
/// Enter) is verified the way Collie does: the text goes in only while the box is empty, and Enter follows only once
/// the box shows exactly that text, checked again on the host. Removing this file and its line in the composition
/// root removes the guard.
public struct SendGuard: HerdrControl {
    private let control: any HerdrControl
    private let reader: any PaneReader
    private let sleep: Pause

    /// - Parameter sleep: waits between the reads that look for the typed text in the input box.
    public init(
        _ control: any HerdrControl, reader: any PaneReader,
        sleep: @escaping Pause = taskSleep
    ) {
        self.control = control
        self.reader = reader
        self.sleep = sleep
    }

    public enum Refusal: Error, Equatable, Sendable, CustomStringConvertible {
        /// The pane shows a dialog; `typed` says whether some of the prompt's text already went in before it showed.
        case dialog(question: String?, typed: Bool)
        case unreadable(String)
        /// The input box already holds text the app did not type.
        case occupied(String)
        /// The typed text never showed in the input box.
        case unverified
        /// The screen failed the host's check right before a request.
        case changed(typed: Bool)

        public var description: String {
            switch self {
            case .dialog(let question, let typed):
                let asking = question.map { "The agent is asking “\($0)”" } ?? "The agent is showing a dialog"
                return typed
                    ? "\(asking). It appeared while typing, so the text may have gone to it and Enter was not sent."
                    : "\(asking). Answer it in Herdr first; nothing was sent."
            case .unreadable(let reason):
                return "Could not check the pane's screen before sending: \(reason)"
            case .occupied(let draft):
                return "The agent's input box already holds “\(draft)”. Clear it in Herdr first; nothing was sent."
            case .unverified:
                return "The text did not show in the agent's input box, so Enter was not sent. Check the pane in Herdr."
            case .changed(let typed):
                return typed
                    ? "The pane's screen changed after typing, so Enter was not sent. Check the pane in Herdr."
                    : "The pane's screen changed just before sending; nothing was sent."
            }
        }
    }

    public func perform(_ requests: [HerdrRequest]) async throws {
        var typed = false
        var index = requests.startIndex
        while index < requests.endIndex {
            let request = requests[index]
            guard request.typesIntoPane, !Self.onlyCancels(request) else {
                try await control.perform([request])
                index += 1
                continue
            }
            let screen = try await read(request.pane, typed: typed)
            if case .sendText(let pane, let text) = request, index + 1 < requests.endIndex,
                requests[index + 1] == .sendKeys(pane, [.enter]), let box = InputBox(on: screen)
            {
                try await prompt(text, to: pane, into: box)
                index += 2
            } else {
                try await send(.checked(Self.check(nil), request), typed: typed)
                index += 1
            }
            typed = true
        }
    }

    /// Types `text` into the empty input box, waits until the box shows it, then sends Enter.
    private func prompt(_ text: String, to pane: PaneID, into box: InputBox) async throws {
        if let draft = box.draft { throw Refusal.occupied(draft) }
        try await send(.checked(Self.check(box), .sendText(pane, text)), typed: false)
        let sent = text.replacing("\u{1B}[200~", with: "").replacing("\u{1B}[201~", with: "")
        for attempt in 0..<ScreenWait.reads {
            if attempt > 0 { try await sleep(ScreenWait.interval) }
            guard let ansi = try? await reader.screen(of: pane) else { continue }
            let screen = Screen(ansi: ansi)
            if let dialog = Dialog(on: screen) { throw Refusal.dialog(question: dialog.question, typed: true) }
            if let box = InputBox(on: screen), box.carries(sent) {
                try await send(.checked(Self.check(box), .sendKeys(pane, [.enter])), typed: true)
                return
            }
        }
        throw Refusal.unverified
    }

    private func read(_ pane: PaneID, typed: Bool) async throws(Refusal) -> Screen {
        let screen: Screen
        do {
            screen = Screen(ansi: try await reader.screen(of: pane))
        } catch {
            throw .unreadable(String(describing: error))
        }
        if let dialog = Dialog(on: screen) {
            throw .dialog(question: dialog.question, typed: typed)
        }
        return screen
    }

    private func send(_ request: HerdrRequest, typed: Bool) async throws {
        do {
            try await control.perform([request])
        } catch let error as HerdrError where error == .screenChanged {
            throw Refusal.changed(typed: typed)
        }
    }

    /// Escape and Control-C back out of a dialog instead of answering it, so they go through while one shows.
    static func onlyCancels(_ request: HerdrRequest) -> Bool {
        guard case .sendKeys(_, let keys) = request else { return false }
        return !keys.isEmpty && keys.allSatisfy(\.cancels)
    }

    /// The host refuses on a dialog's footer, and, with a box, unless the box still shows as it did here.
    static func check(_ box: InputBox?) -> ScreenCheck {
        ScreenCheck(
            rows: box?.rows ?? [], refusing: Dialog.hints, window: (box?.rows.count ?? 0) + InputBox.tailLines)
    }
}
