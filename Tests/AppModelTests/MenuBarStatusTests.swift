import FabrikaterCore
import Foundation
import HerdrKit
import Testing
import TranscriptKit

@testable import AppModel

@MainActor
struct MenuBarStatusTests {
    private struct NoTranscripts: TranscriptService {
        func transcript(of log: SessionLog, bytes: Int) async throws -> Transcript { Transcript() }
    }

    private let refactor = PaneID("w1:p1")!
    private let codex = PaneID("w1:pB")!

    private func herd() throws -> Herd {
        try Herd(snapshotReply: Fixture.data(named: "snapshot.synthetic.json"))
    }

    private func makeStore(host: String = "arch") -> AppStore {
        AppStore(
            herdUpdates: AsyncStream { $0.finish() }, transcripts: NoTranscripts(), control: FakeControl(), host: host)
    }

    private func finished(_ pane: PaneID, in herd: Herd) -> Herd {
        var herd = herd
        herd.panes = herd.panes.map { candidate in
            var candidate = candidate
            if candidate.id == pane { candidate.agentStatus = .done }
            return candidate
        }
        return herd
    }

    @Test func listsTheNeedsYouPanesWithTheirState() throws {
        let store = makeStore()
        store.apply(.herd(try herd()))
        store.apply(.herd(finished(refactor, in: try herd())))
        let status = MenuBarStatus(needsYou: store.needsYou, connection: store.connection, host: "arch")
        #expect(status.rows.map(\.id) == [codex, refactor])
        #expect(status.rows.map(\.title) == ["codex · Needs input", "Synthetic refactor · Done"])
        #expect(status.count == "2")
        #expect(status.symbol == "bell.badge")
        #expect(status.heading == "arch: 2 panes need you")
        #expect(status.spokenLabel == "fabrikater, arch: 2 panes need you")
    }

    @Test func aQuietHostShowsAPlainBellAndNoCount() {
        let status = MenuBarStatus(needsYou: NeedsYou(), connection: .connected, host: "arch")
        #expect(status.rows.isEmpty)
        #expect(status.count == nil)
        #expect(status.symbol == "bell")
        #expect(status.heading == "arch: nothing needs you")
    }

    @Test func anUnreachableHostKeepsTheLastPanesAndSaysSo() throws {
        let store = makeStore()
        store.apply(.herd(try herd()))
        store.apply(.failed("no route to host"))
        let stale = MenuBarStatus(needsYou: store.needsYou, connection: store.connection, host: "arch")
        #expect(stale.rows.map(\.id) == [codex])
        #expect(stale.symbol == "bell.slash")
        #expect(stale.heading == "arch is offline; last known: 1 pane needs you")

        let offline = MenuBarStatus(needsYou: NeedsYou(), connection: .offline("no route"), host: "arch")
        #expect(offline.heading == "arch is offline")
        #expect(
            MenuBarStatus(needsYou: NeedsYou(), connection: .connecting, host: "devbox").heading
                == "Connecting to devbox…")
    }

    @Test func followsAHostSwitch() throws {
        let herd = try herd()
        let preferences = PreferencesStore(connectedHost: "arch")
        let session = HostSession(preferences: preferences) { host in
            let store = self.makeStore(host: host)
            if host == "arch" { store.apply(.herd(herd)) }
            return store
        }
        #expect(session.menuBar.rows.map(\.id) == [codex])
        preferences.setHostText("devbox")
        preferences.connect()
        #expect(session.menuBar.rows.isEmpty)
        #expect(session.menuBar.heading == "Connecting to devbox…")
    }

    @Test func theToggleIsSavedWithThePreferences() {
        let storage = InMemoryPreferencesStorage()
        let session = HostSession(preferences: PreferencesStore(storage: storage)) { _ in self.makeStore() }
        #expect(session.showsMenuBarItem)
        session.showsMenuBarItem = false
        #expect(!storage.preferences.showsMenuBarItem)
        #expect(!PreferencesStore(storage: storage).preferences.showsMenuBarItem)
    }
}
