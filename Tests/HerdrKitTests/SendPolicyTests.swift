import FabrikaterCore
import Testing

@testable import HerdrKit

struct SendPolicyTests {
    private let pane = PaneID("w2:p1")!
    private let herd = Herd(
        workspaces: [.init(id: "w1", label: "work", number: 1), .init(id: "w2", label: "fabrikater-test", number: 2)],
        tabs: [],
        panes: [
            Herd.Pane(id: PaneID("w1:p1")!, tabID: "w1:t1", workspaceID: "w1"),
            Herd.Pane(id: PaneID("w2:p1")!, tabID: "w2:t1", workspaceID: "w2"),
        ]
    )

    @Test func readsTheAllowlistFromTheEnvironment() {
        #expect(SendPolicy(environment: [:], isDebugBuild: true).allowedLabels == ["fabrikater-test"])
        #expect(SendPolicy(environment: [:], isDebugBuild: false).allowedLabels == nil)
        #expect(SendPolicy(environment: ["FABRIKATER_SEND_ALLOWLIST": ""], isDebugBuild: false).allowedLabels == [])
        #expect(
            SendPolicy(environment: ["FABRIKATER_SEND_ALLOWLIST": " a , ,b "], isDebugBuild: false).allowedLabels
                == ["a", "b"])
    }

    @Test func allowsAListedWorkspace() async throws {
        try await SendPolicy(allowedLabels: ["fabrikater-test"]).authorize(pane) { herd }
    }

    @Test func refusesAnUnlistedWorkspace() async {
        await #expect(throws: SendPolicy.Refusal.notAllowed(workspace: "work")) {
            try await SendPolicy(allowedLabels: ["fabrikater-test"]).authorize(PaneID("w1:p1")!) { herd }
        }
    }

    @Test func emptyListRefusesEverything() async {
        await #expect(throws: SendPolicy.Refusal.self) {
            try await SendPolicy(allowedLabels: []).authorize(pane) { herd }
        }
    }

    @Test func refusesWhenTheFreshReadFailsOrThePaneIsGone() async {
        let policy = SendPolicy(allowedLabels: ["fabrikater-test"])
        await #expect(throws: SendPolicy.Refusal.snapshotFailed("offline")) {
            try await policy.authorize(pane) { throw HerdrError("offline") }
        }
        await #expect(throws: SendPolicy.Refusal.paneMissing) {
            try await policy.authorize(pane) { Herd() }
        }
    }

    @Test func noLimitSkipsTheRead() async throws {
        try await SendPolicy(allowedLabels: nil).authorize(pane) { throw HerdrError("never read") }
    }
}
