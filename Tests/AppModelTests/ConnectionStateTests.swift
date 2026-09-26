import Testing

@testable import AppModel

struct ConnectionStateTests {
    @Test func onlyAStaleHerdClaimsTheLastKnownState() {
        #expect(ConnectionState.stale("x").title == "Offline, showing the last known state")
        #expect(ConnectionState.offline("x").title == "Offline")
    }

    @Test func theFailureIsTheReasonOfAFailedRead() {
        #expect(ConnectionState.connecting.failure == nil)
        #expect(ConnectionState.connected.failure == nil)
        #expect(ConnectionState.stale("gone").failure == "gone")
        #expect(ConnectionState.offline("gone").failure == "gone")
    }

    @Test func theEmptySidebarSaysWhyItIsEmpty() {
        #expect(ConnectionState.connecting.emptySidebar == EmptySidebar(title: "Connecting…", detail: nil))
        #expect(ConnectionState.connected.emptySidebar.title == "No Workspaces")
        #expect(ConnectionState.offline("gone").emptySidebar == EmptySidebar(title: "Offline", detail: "gone"))
    }
}
