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

/// `HerdrService` over a `HostCommandRunner`.
public struct HerdrClient: HerdrService {
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
