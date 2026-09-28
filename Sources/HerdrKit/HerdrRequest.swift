import FabrikaterCore
import Foundation

/// One Herdr API call that changes something on the host (docs/architecture.md, "Control: requests").
public enum HerdrRequest: Equatable, Sendable {
    /// Brings the pane, its tab and its workspace to the front of Herdr's own screen.
    case focus(PaneID)
    /// Types `text` into the pane as raw bytes, without submitting it.
    case sendText(PaneID, String)
    case sendKeys(PaneID, [Key])
    /// The request, sent only if the pane's screen, read on the host right before it, passes the check.
    indirect case checked(ScreenCheck, HerdrRequest)

    /// Key names from Herdr's `pane.send_keys` grammar.
    public enum Key: String, Equatable, Sendable {
        case enter = "Enter"
        case escape = "Escape"
        case ctrlC = "ctrl+c"
    }

    public var pane: PaneID {
        switch self {
        case .focus(let pane), .sendText(let pane, _), .sendKeys(let pane, _): pane
        case .checked(_, let request): request.pane
        }
    }

    /// True for requests that type into the pane, which `SendPolicy` must allow first.
    public var typesIntoPane: Bool {
        switch self {
        case .focus: false
        case .sendText, .sendKeys: true
        case .checked(_, let request): request.typesIntoPane
        }
    }

    /// The requests that submit `text` as a prompt: the text, then Enter.
    ///
    /// `pane.send_text` writes raw bytes, so a newline would be an Enter keypress and submit early. Multi-line text
    /// goes inside bracketed-paste markers instead, which agent TUIs read as one pasted block.
    public static func prompt(_ text: String, to pane: PaneID) -> [HerdrRequest] {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return [] }
        let typed = body.contains(where: \.isNewline) ? "\u{1B}[200~" + body + "\u{1B}[201~" : body
        return [.sendText(pane, typed), .sendKeys(pane, [.enter])]
    }

    /// The lines the requests script reads on stdin (`HostCommand.herdrRequests`): the request as one line for
    /// Herdr's API socket, `{"id":…,"method":…,"params":{…}}`, after its screen check's lines if it has one.
    func lines(id: String) -> [String] {
        guard case .checked(let check, let request) = self else { return [line(id: id)] }
        return check.lines(for: request.pane) + request.lines(id: id)
    }

    func line(id: String) -> String {
        if case .checked(_, let request) = self { return request.line(id: id) }
        let request: [String: Any] =
            switch self {
            case .checked: [:]
            case .focus(let pane):
                ["id": id, "method": "pane.focus", "params": ["pane_id": pane.rawValue]]
            case .sendText(let pane, let text):
                ["id": id, "method": "pane.send_text", "params": ["pane_id": pane.rawValue, "text": text]]
            case .sendKeys(let pane, let keys):
                [
                    "id": id, "method": "pane.send_keys",
                    "params": ["pane_id": pane.rawValue, "keys": keys.map(\.rawValue)],
                ]
            }
        // Control characters, quotes and newlines come out escaped, so the line holds no raw newline.
        let data = try? JSONSerialization.data(
            withJSONObject: request, options: [.sortedKeys, .withoutEscapingSlashes])
        return String(decoding: data ?? Data(), as: UTF8.self)
    }
}

/// Performs `HerdrRequest`s. `HerdrClient` is the real one; tests use a fake.
public protocol HerdrControl: Sendable {
    /// Runs the requests in order and throws on the first one Herdr refuses.
    func perform(_ requests: [HerdrRequest]) async throws
}
