import Foundation
import Testing

@testable import FabrikaterCore

/// Guards the value types against a real, scrubbed `herdr api snapshot` from `scripts/capture-fixtures.sh`.
/// Asserts only invariants, so a fresh capture with different panes still passes.
struct CapturedSnapshotTests {
    private struct Envelope: Decodable {
        struct Result: Decodable { let snapshot: Snapshot }
        struct Snapshot: Decodable {
            let panes: [Pane]
            let agents: [Pane]
        }
        struct Pane: Decodable {
            let paneId: PaneID
            let agent: AgentKind?
            let agentStatus: AgentStatus
        }
        let result: Result
    }

    private func snapshot() throws -> Envelope.Snapshot {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(Envelope.self, from: Fixture.data(named: "snapshot.json")).result.snapshot
    }

    @Test func decodesEveryPaneAndAgent() throws {
        let snapshot = try snapshot()
        #expect(!snapshot.panes.isEmpty)
        #expect(!snapshot.agents.isEmpty)
    }

    @Test func agentsAreExactlyThePanesWithAnAgent() throws {
        let snapshot = try snapshot()
        let panesWithAgent = snapshot.panes.filter { $0.agent != nil }
        #expect(Set(panesWithAgent.map(\.paneId)) == Set(snapshot.agents.map(\.paneId)))
        for agent in snapshot.agents {
            let pane = try #require(snapshot.panes.first { $0.paneId == agent.paneId })
            #expect(pane.agent == agent.agent)
            #expect(pane.agentStatus == agent.agentStatus)
        }
    }
}
