import FabrikaterCore
import Foundation
import HerdrKit
import PromptKit

/// A `HerdrControl` that reads the pane's screen before each request that types into it, and refuses while the agent
/// shows a dialog there: typed text would answer the dialog instead of reaching the agent (docs/parsing.md 4.4).
///
/// Requests go one at a time, so the check also runs between a prompt's text and its Enter: a dialog that appeared
/// while the text was typed keeps the Enter from confirming it. Removing this file and its line in the composition
/// root removes the guard.
public struct SendGuard: HerdrControl {
    private let control: any HerdrControl
    private let reader: any PaneReader

    public init(_ control: any HerdrControl, reader: any PaneReader) {
        self.control = control
        self.reader = reader
    }

    public enum Refusal: Error, Equatable, Sendable, CustomStringConvertible {
        /// The pane shows a dialog; `typed` says whether some of the prompt's text already went in before it showed.
        case dialog(question: String?, typed: Bool)
        case unreadable(String)

        public var description: String {
            switch self {
            case .dialog(let question, let typed):
                let asking = question.map { "The agent is asking “\($0)”" } ?? "The agent is showing a dialog"
                return typed
                    ? "\(asking). It appeared while typing, so the text may have gone to it and Enter was not sent."
                    : "\(asking). Answer it in Herdr first; nothing was sent."
            case .unreadable(let reason):
                return "Could not check the pane's screen before sending: \(reason)"
            }
        }
    }

    public func perform(_ requests: [HerdrRequest]) async throws {
        var typed = false
        for request in requests {
            if request.typesIntoPane {
                try await check(request.pane, typed: typed)
                typed = true
            }
            try await control.perform([request])
        }
    }

    private func check(_ pane: PaneID, typed: Bool) async throws(Refusal) {
        let screen: String
        do {
            screen = try await reader.screen(of: pane)
        } catch {
            throw .unreadable(String(describing: error))
        }
        if let dialog = Dialog(on: Screen(ansi: screen)) {
            throw .dialog(question: dialog.question, typed: typed)
        }
    }
}
