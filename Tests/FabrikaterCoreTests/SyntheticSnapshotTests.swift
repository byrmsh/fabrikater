import Foundation
import Testing

@testable import FabrikaterCore

/// Guards the value types against the snapshot shapes in docs/architecture.md, using a hand-written fixture.
struct SyntheticSnapshotTests {
    private struct Envelope: Decodable {
        struct Result: Decodable { let snapshot: Snapshot }
        struct Snapshot: Decodable { let panes: [Pane] }
        struct Pane: Decodable {
            let paneId: PaneID
            let agent: AgentKind?
            let agentStatus: AgentStatus
        }
        let result: Result
    }

    @Test func decodesEveryPaneOfTheSyntheticSnapshot() throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let panes = try decoder.decode(Envelope.self, from: Fixture.data(named: "snapshot.synthetic.json"))
            .result.snapshot.panes

        #expect(panes.map(\.paneId.rawValue) == ["w1:p1", "w1:pA", "w1:pB", "w2:p1"])
        #expect(panes.map(\.agent) == [.claude, nil, .codex, .claude])
        #expect(panes.map(\.agentStatus) == [.working, .unknown, .blocked, .done])
    }
}
