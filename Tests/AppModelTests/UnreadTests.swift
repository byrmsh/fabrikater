import FabrikaterCore
import Foundation
import HerdrKit
import Testing
import TranscriptKit

@testable import AppModel

@MainActor
struct UnreadTests {
    private struct NoTranscripts: TranscriptService {
        func claudeTranscript(session: SessionID, bytes: Int) async throws -> Transcript { Transcript() }
    }

    private let refactor = PaneID("w1:p1")!
    private let scratch = PaneID("w2:p1")!
    private let codex = PaneID("w1:pB")!

    private func makeStore(_ notes: any PaneNotesStore = InMemoryPaneNotesStore()) throws -> (AppStore, Herd) {
        let herd = try Herd(snapshotReply: Fixture.data(named: "snapshot.synthetic.json"))
        let store = AppStore(
            herdUpdates: AsyncStream { $0.finish() }, transcripts: NoTranscripts(), control: FakeControl(), notes: notes
        )
        store.apply(.herd(herd))
        return (store, herd)
    }

    private func setting(_ id: PaneID, to status: AgentStatus, in herd: Herd) -> Herd {
        var herd = herd
        herd.panes = herd.panes.map { pane in
            var pane = pane
            if pane.id == id { pane.agentStatus = status }
            return pane
        }
        return herd
    }

    private func unreadIDs(_ store: AppStore) -> Set<PaneID> {
        Set(store.sections.panes.filter(\.isUnread).map(\.id))
    }

    @Test func nothingIsUnreadAtFirstSight() throws {
        let (store, herd) = try makeStore()
        #expect(unreadIDs(store).isEmpty)
        #expect(store.sections == SidebarSection.sections(for: herd))
    }

    @Test(arguments: [AgentStatus.done, .idle])
    func aTurnEndingOnAnotherPaneMarksItUnread(_ status: AgentStatus) throws {
        let (store, herd) = try makeStore()
        store.apply(.herd(setting(refactor, to: status, in: herd)))
        #expect(unreadIDs(store) == [refactor])
    }

    @Test func aTurnEndingOnTheSelectedPaneStaysRead() throws {
        let (store, herd) = try makeStore()
        store.perform(.selectPane(refactor))
        store.apply(.herd(setting(refactor, to: .done, in: herd)))
        #expect(unreadIDs(store).isEmpty)
    }

    @Test func otherChangesLeavePanesRead() throws {
        let (store, herd) = try makeStore()
        var next = setting(refactor, to: .blocked, in: herd)
        next = setting(scratch, to: .idle, in: next)
        next = setting(codex, to: .done, in: next)
        store.apply(.herd(next))
        #expect(unreadIDs(store).isEmpty)
    }

    @Test func selectingAPaneReadsItAndItStaysRead() throws {
        let (store, herd) = try makeStore()
        let done = setting(refactor, to: .done, in: herd)
        store.apply(.herd(done))
        store.perform(.selectPane(refactor))
        #expect(unreadIDs(store).isEmpty)
        store.perform(.selectPane(scratch))
        store.apply(.herd(done))
        #expect(unreadIDs(store).isEmpty)
    }

    @Test func aPaneStaysUnreadWhileItWorksAgain() throws {
        let (store, herd) = try makeStore()
        store.apply(.herd(setting(refactor, to: .done, in: herd)))
        store.apply(.herd(herd))
        #expect(unreadIDs(store) == [refactor])
    }

    @Test func unreadSurvivesARelaunch() throws {
        let notes = InMemoryPaneNotesStore()
        let (store, herd) = try makeStore(notes)
        store.apply(.herd(setting(refactor, to: .done, in: herd)))
        let (relaunched, _) = try makeStore(notes)
        #expect(unreadIDs(relaunched) == [refactor])
        relaunched.perform(.selectPane(refactor))
        #expect(notes.load().unread.isEmpty)
    }

    @Test func theTabAndThePinnedCopyShowItAndVoiceOverSaysIt() throws {
        let (store, herd) = try makeStore()
        store.perform(.togglePin(refactor))
        store.apply(.herd(setting(refactor, to: .done, in: herd)))
        let rows = store.sections.flatMap(\.rows)
        let pinned = try #require(rows.first?.panes.first)
        #expect(pinned.id == refactor && pinned.isUnread)
        #expect(pinned.spokenLabel == "Synthetic refactor, Claude, Done, Unread")
        let tab = try #require(
            rows.compactMap { row -> TabRow? in
                if case .tab(let tab) = row { tab } else { nil }
            }.first { $0.panes.contains { $0.id == refactor } })
        #expect(tab.isUnread)
        #expect(tab.spokenLabel.hasSuffix(", Unread"))
    }

    @Test func notesWithoutAnUnreadFieldDecodeAndUnreadRoundTrips() throws {
        let old = try JSONDecoder().decode(PaneNotes.self, from: Data(#"{"names":{},"pins":["w2:p1"]}"#.utf8))
        #expect(old == PaneNotes(pins: [scratch]))
        let notes = PaneNotes(unread: [scratch, refactor])
        #expect(try JSONDecoder().decode(PaneNotes.self, from: JSONEncoder().encode(notes)) == notes)
    }
}
