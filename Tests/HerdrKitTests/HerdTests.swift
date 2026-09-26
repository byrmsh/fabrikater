import FabrikaterCore
import Foundation
import Testing

@testable import HerdrKit

struct HerdTests {
    @Test func decodesTheSyntheticSnapshot() throws {
        let herd = try Herd(snapshotReply: Fixture.data(named: "snapshot.synthetic.json"))
        #expect(herd.workspaces.map(\.label) == ["Synthetic A", "fabrikater-test"])
        #expect(herd.tabs.map(\.id) == ["w1:t1", "w1:t2", "w2:t1"])
        #expect(herd.panes.map(\.id.rawValue) == ["w1:p1", "w1:pA", "w1:pB", "w2:p1"])
        #expect(herd.panes.map(\.agent) == [.claude, nil, .codex, .claude])
        #expect(herd.panes[0].title == "Synthetic refactor")
        #expect(herd.panes[0].cwd == "/home/user/project-1")
        #expect(herd.panes[0].foregroundCwd == "/home/user/project-1")
        #expect(herd.panes.map(\.revision) == [17, 3, 9, 2])
    }

    @Test func decodesTheCapturedSnapshot() throws {
        let herd = try Herd(snapshotReply: Fixture.data(named: "snapshot.json"))
        #expect(!herd.workspaces.isEmpty)
        #expect(!herd.panes.isEmpty)
        for pane in herd.panes {
            #expect(herd.tab(pane.tabID)?.workspaceID == pane.workspaceID)
        }
        #expect(herd.panes.contains { $0.sessionID != nil })
    }

    @Test func ignoresUnknownFieldsAndSkipsBrokenRecords() throws {
        let json = #"""
            {"id":"x","result":{"type":"session_snapshot","snapshot":{"new_top_level":1,
              "workspaces":[{"workspace_id":"w1","label":"A","number":2,"agent_status":"sleeping","shiny":true},
                            {"label":"no id"}],
              "tabs":[{"tab_id":"w1:t1","workspace_id":"w1","label":"t","number":1}],
              "panes":[{"pane_id":"w1:p1","tab_id":"w1:t1","workspace_id":"w1","agent":"aider","agent_status":"idle"},
                       {"pane_id":"w1:p1; rm -rf ~","tab_id":"w1:t1","workspace_id":"w1"}]}}}
            """#
        let herd = try Herd(snapshotReply: Data(json.utf8))
        #expect(herd.workspaces == [Herd.Workspace(id: "w1", label: "A", number: 2, agentStatus: .unknown)])
        #expect(herd.panes.map(\.id.rawValue) == ["w1:p1"])
        #expect(herd.panes[0].agent == .other("aider"))
    }

    @Test func reportsAnErrorReply() {
        let json = #"{"id":"x","error":{"message":"server busy"}}"#
        #expect(throws: HerdrError("server busy")) { try Herd(snapshotReply: Data(json.utf8)) }
        #expect(throws: HerdrError.self) { try Herd(snapshotReply: Data("not json".utf8)) }
    }

    @Test func acceptsASessionOnlyForThePanesCurrentAgent() throws {
        let id = try #require(PaneID("w1:p1"))
        let uuid = "00000000-0000-4000-8000-000000000001"
        func pane(agent: AgentKind?, session: Herd.AgentSession?) -> Herd.Pane {
            Herd.Pane(id: id, tabID: "w1:t1", workspaceID: "w1", agent: agent, agentSession: session)
        }
        #expect(
            pane(agent: .claude, session: .init(agent: "claude", kind: "id", value: uuid)).sessionID?.rawValue == uuid)
        #expect(pane(agent: .claude, session: .init(agent: nil, kind: "id", value: uuid)).sessionID?.rawValue == uuid)
        #expect(pane(agent: .codex, session: .init(agent: "claude", kind: "id", value: uuid)).sessionID == nil)
        #expect(pane(agent: .claude, session: .init(agent: "claude", kind: "path", value: uuid)).sessionID == nil)
        #expect(pane(agent: .claude, session: .init(agent: "claude", kind: "id", value: "../../etc")).sessionID == nil)
        #expect(pane(agent: nil, session: .init(agent: "claude", kind: "id", value: uuid)).sessionID == nil)
    }
}
