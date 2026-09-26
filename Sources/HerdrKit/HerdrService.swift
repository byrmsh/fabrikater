import FabrikaterCore
import Foundation
import HostKit

/// Reads Herdr's state. `HerdrClient` is the real one; tests use a fake.
public protocol HerdrService: Sendable {
    func snapshot() async throws -> Herd
    /// One element per event Herdr reports, and one when the subscription starts. The elements carry no state:
    /// they only say "re-read the snapshot". Ends or throws when the channel drops.
    func events() -> AsyncThrowingStream<Void, any Error>
}

/// Reads what a pane shows. `HerdrClient` is the real one; tests use a fake.
public protocol PaneReader: Sendable {
    /// The pane's visible screen as ANSI text.
    func screen(of pane: PaneID) async throws -> String
}

/// `HerdrService`, `HerdrControl` and `PaneReader` over a `HostCommandRunner`.
public struct HerdrClient: HerdrService, HerdrControl, PaneReader {
    /// One fixed subscription instead of per-pane `pane.agent_status_changed` (docs/milestones.md, M1).
    public static let subscriptions = [
        "workspace.created", "workspace.updated", "workspace.renamed", "workspace.moved", "workspace.reordered",
        "workspace.closed", "tab.created", "tab.closed", "tab.renamed", "tab.moved", "pane.created", "pane.closed",
        "pane.updated", "pane.moved", "pane.exited", "pane.agent_detected",
    ]

    private let runner: any HostCommandRunner

    public init(runner: any HostCommandRunner) {
        self.runner = runner
    }

    public func snapshot() async throws -> Herd {
        try Herd(snapshotReply: try await runner.run(.herdrSnapshot))
    }

    public func screen(of pane: PaneID) async throws -> String {
        String(decoding: try await runner.run(.herdrPaneScreen(pane)), as: UTF8.self)
    }

    public func perform(_ requests: [HerdrRequest]) async throws {
        guard !requests.isEmpty else { return }
        let lines = requests.enumerated().map { $1.line(id: "fabrikater\($0 + 1)") + "\n" }
        try Self.checkReplies(
            try await runner.run(.herdrRequests, input: Data(lines.joined().utf8)), count: requests.count)
    }

    public func events() -> AsyncThrowingStream<Void, any Error> {
        let lines = runner.lines(.herdrEvents, input: Self.subscribeRequest)
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var acknowledged = false
                    for try await line in lines where !line.isEmpty {
                        if !acknowledged {
                            try Self.checkAcknowledgement(line)
                            acknowledged = true
                        }
                        continuation.yield()
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Herdr replies one line per request: a `result` when it was done, an `error` object when it was refused.
    /// Fewer replies than requests, or a line that is neither, means the rest may not have happened.
    static func checkReplies(_ output: Data, count: Int) throws(HerdrError) {
        let lines = output.split(separator: 0x0A)
        for line in lines {
            let reply = try? JSONSerialization.jsonObject(with: line) as? [String: Any]
            if let error = reply?["error"] as? [String: Any] {
                throw HerdrError(error["message"] as? String ?? "Herdr refused the request")
            }
            guard reply?["result"] != nil else { throw HerdrError("Herdr sent a reply that is not JSON") }
        }
        guard lines.count >= count else { throw HerdrError("Herdr did not answer every request") }
    }

    /// The first line back is `{"id":"sub1","result":{"type":"subscription_started"}}`, or an error reply.
    static func checkAcknowledgement(_ line: String) throws(HerdrError) {
        let reply = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any]
        guard let reply, reply["error"] == nil else {
            throw HerdrError("Herdr refused the event subscription")
        }
    }

    /// The one line written to the API socket: `{"id":"sub1","method":"events.subscribe","params":{…}}`.
    static var subscribeRequest: Data {
        let types = subscriptions.map { #"{"type":"\#($0)"}"# }.joined(separator: ",")
        return Data((#"{"id":"sub1","method":"events.subscribe","params":{"subscriptions":["# + types + "]}}\n").utf8)
    }
}
