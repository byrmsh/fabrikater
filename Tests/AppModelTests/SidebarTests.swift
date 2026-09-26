import FabrikaterCore
import HerdrKit
import Testing

@testable import AppModel

struct SidebarTests {
    @Test func buildsSectionsFromTheSyntheticSnapshot() throws {
        let herd = try Herd(snapshotReply: Fixture.data(named: "snapshot.synthetic.json"))
        let sections = SidebarSection.sections(for: herd)

        #expect(sections.map(\.title) == ["Synthetic A", "fabrikater-test"])
        #expect(sections[0].rows.map(\.id) == ["w1:t1", "w1:pB"])
        guard case .tab(let tab) = sections[0].rows[0] else {
            Issue.record("a tab with two panes stays a tab")
            return
        }
        #expect(tab.label == "api")
        #expect(tab.panes.map(\.label) == ["Synthetic refactor", "zsh"])
        #expect(tab.panes.map(\.isDimmed) == [false, true])
        #expect(
            sections[1].rows == [.pane(PaneRow(id: PaneID("w2:p1")!, label: "Scratch", status: .done, agent: .claude))])
    }

    @Test func rowsSpeakTheirLabelAgentAndStatus() {
        let pane = PaneRow(id: PaneID("w1:p1")!, label: "Refactor", status: .blocked, agent: .claude)
        let shell = PaneRow(id: PaneID("w1:p2")!, label: "zsh", status: .unknown, agent: nil)
        #expect(pane.spokenLabel == "Refactor, Claude, Needs input")
        #expect(shell.spokenLabel == "zsh, Shell, Unknown")
        #expect(TabRow(id: "w1:t1", label: "api", status: .working, panes: [pane]).spokenLabel == "api, Working")
    }

    @Test func ordersWorkspacesAndTabsByNumber() {
        let herd = Herd(
            workspaces: [.init(id: "w9", label: "second", number: 2), .init(id: "w1", label: "first", number: 1)],
            tabs: [
                .init(id: "w1:t2", workspaceID: "w1", label: "b", number: 2),
                .init(id: "w1:t1", workspaceID: "w1", label: "a", number: 1),
            ],
            panes: [
                Herd.Pane(id: PaneID("w1:p2")!, tabID: "w1:t2", workspaceID: "w1"),
                Herd.Pane(id: PaneID("w1:p1")!, tabID: "w1:t1", workspaceID: "w1"),
            ]
        )
        let sections = SidebarSection.sections(for: herd)
        #expect(sections.map(\.id) == ["w1", "w9"])
        #expect(sections[0].rows.map(\.id) == ["w1:p1", "w1:p2"])
        #expect(sections[1].rows.isEmpty)
    }

    @Test func labelFallsBackFromTitleToTabToPaneID() {
        let id = PaneID("w1:p1")!
        let tab = Herd.Tab(id: "w1:t1", workspaceID: "w1", label: "tab label", number: 1)
        let emptyTab = Herd.Tab(id: "w1:t1", workspaceID: "w1", label: "", number: 1)
        func pane(title: String?) -> Herd.Pane { Herd.Pane(id: id, tabID: "w1:t1", workspaceID: "w1", title: title) }

        #expect(PaneRow.label(for: pane(title: "Title"), tab: tab) == "Title")
        #expect(PaneRow.label(for: pane(title: "  "), tab: tab) == "tab label")
        #expect(PaneRow.label(for: pane(title: nil), tab: emptyTab) == "w1:p1")
    }
}
