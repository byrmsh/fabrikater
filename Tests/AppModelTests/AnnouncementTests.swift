import FabrikaterCore
import Foundation
import HerdrKit
import Testing
import TranscriptKit

@testable import AppModel

@MainActor
struct AnnouncementTests {
    private let refactor = PaneRow(id: PaneID("w1:p1")!, label: "Refactor", status: .blocked, agent: .claude)
    private let scratch = PaneRow(id: PaneID("w2:p1")!, label: "Scratch", status: .done, agent: .claude, isUnread: true)

    private func state(_ connection: ConnectionState = .connected, _ needsYou: [PaneRow] = []) -> Announcement.State {
        Announcement.State(connection: connection, needsYou: needsYou)
    }

    @Test func aBlockedPaneJoiningNeedsYouIsSaid() {
        #expect(Announcement.changes(from: state(), to: state(.connected, [refactor])) == ["Refactor needs input"])
    }

    @Test func aFinishedTurnJoiningNeedsYouIsSaid() {
        #expect(
            Announcement.changes(from: state(.connected, [refactor]), to: state(.connected, [refactor, scratch]))
                == ["Scratch finished its turn"])
    }

    @Test func severalPanesJoiningAtOnceAreCounted() {
        #expect(
            Announcement.changes(from: state(), to: state(.connected, [refactor, scratch])) == ["2 panes need you"])
    }

    @Test func panesLeavingOrStayingInNeedsYouAreNotSaid() {
        #expect(
            Announcement.changes(from: state(.connected, [refactor, scratch]), to: state(.connected, [scratch])).isEmpty
        )
        var renamed = refactor
        renamed.label = "Renamed"
        #expect(Announcement.changes(from: state(.connected, [refactor]), to: state(.connected, [renamed])).isEmpty)
    }

    @Test func theFirstFillOfNeedsYouIsNotSaid() {
        #expect(Announcement.changes(from: state(.connecting), to: state(.connected, [refactor])).isEmpty)
    }

    @Test func goingOfflineIsSaid() {
        #expect(
            Announcement.changes(from: state(), to: state(.stale("ssh failed"))) == [
                "Offline, showing the last known state"
            ])
        #expect(Announcement.changes(from: state(.connecting), to: state(.offline("ssh failed"))) == ["Offline"])
    }

    @Test func comingBackIsSaidWithoutTheNeedsYouItBrings() {
        #expect(
            Announcement.changes(from: state(.stale("ssh failed"), []), to: state(.connected, [refactor]))
                == ["Reconnected"])
    }

    @Test func connectingForTheFirstTimeOrStayingOfflineIsNotSaid() {
        #expect(Announcement.changes(from: state(.connecting), to: state()).isEmpty)
        #expect(Announcement.changes(from: state(.stale("a")), to: state(.stale("b"))).isEmpty)
        #expect(Announcement.changes(from: state(.stale("a")), to: state(.offline("b"))).isEmpty)
    }

    @Test func theStoreAnnouncesItsConnectionAndNeedsYou() throws {
        let herd = try Herd(snapshotReply: Fixture.data(named: "snapshot.synthetic.json"))
        let store = AppStore(
            herdUpdates: AsyncStream { $0.finish() }, transcripts: NoTranscripts(), control: FakeControl())
        store.apply(.herd(herd))
        #expect(store.announced.connection == .connected)
        #expect(store.announced.needsYou.map(\.id) == store.needsYou.panes.map(\.id))
    }

    @Test func aPromptCardAnnouncesItsHeadingAndQuestion() throws {
        let store = PromptCardStore(reader: UnreadableScreens(), control: FakeControl())
        #expect(store.announcement == nil)
        let herd = try Herd(snapshotReply: Fixture.data(named: "snapshot.synthetic.json"))
        var pane = try #require(herd.pane(PaneID("w1:p1")!))
        pane.agentStatus = .blocked
        pane.agent = .codex
        store.show(pane, isOnline: true)
        #expect(store.announcement == "Waiting for Input. \(PromptCardStore.unknownMessage)")
    }

    private struct NoTranscripts: TranscriptService {
        func transcript(of log: SessionLog, bytes: Int) async throws -> Transcript { Transcript() }
    }
}
