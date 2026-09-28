import FabrikaterCore
import Foundation
import HerdrKit
import Synchronization
import Testing
import TranscriptKit

@testable import AppModel

@MainActor
struct SortingTests {
    private struct NoTranscripts: TranscriptService {
        func transcript(of log: SessionLog, bytes: Int) async throws -> Transcript { Transcript() }
    }

    private final class Clock: Sendable {
        let time = Mutex(Date(timeIntervalSince1970: 1_000_000))
        func advance(by seconds: TimeInterval) { time.withLock { $0 += seconds } }
    }

    private let refactor = PaneID("w1:p1")!
    private let shell = PaneID("w1:pA")!
    private let codex = PaneID("w1:pB")!
    private let scratch = PaneID("w2:p1")!
    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func herd() throws -> Herd {
        try Herd(snapshotReply: Fixture.data(named: "snapshot.synthetic.json"))
    }

    private func sections(_ times: [PaneID: Date]) throws -> [SidebarSection] {
        SidebarSection.sections(for: try herd()).active(times)
    }

    private func rowIDs(_ sections: [SidebarSection]) -> [[String]] {
        sections.map { $0.rows.map(\.id) }
    }

    private func changing(_ herd: Herd, _ id: PaneID, _ change: (inout Herd.Pane) -> Void) -> Herd {
        var herd = herd
        if let index = herd.panes.firstIndex(where: { $0.id == id }) {
            change(&herd.panes[index])
        }
        return herd
    }

    // MARK: The order

    @Test func herdrOrderLeavesTheRowsAsTheyAre() throws {
        let sections = try sections([codex: start])
        #expect(sections.sorted(.herdr) == sections)
    }

    @Test func recentActivityPutsTheNewestRowFirstWithinItsWorkspace() throws {
        let sorted = try sections([refactor: start, codex: start + 60, scratch: start + 120]).sorted(.recentActivity)
        #expect(rowIDs(sorted) == [["w1:pB", "w1:t1"], ["w2:p1"]])
    }

    @Test func aTabSortsByItsMostRecentPane() throws {
        let sorted = try sections([codex: start + 60, shell: start + 120]).sorted(.recentActivity)
        #expect(rowIDs(sorted) == [["w1:t1", "w1:pB"], ["w2:p1"]])
    }

    @Test func rowsWithoutActivityFollowInHerdrOrder() throws {
        let sorted = try sections([codex: start]).sorted(.recentActivity)
        #expect(rowIDs(sorted) == [["w1:pB", "w1:t1"], ["w2:p1"]])
    }

    @Test func equalTimesKeepHerdrOrder() throws {
        let sorted = try sections([refactor: start, codex: start]).sorted(.recentActivity)
        #expect(rowIDs(sorted) == [["w1:t1", "w1:pB"], ["w2:p1"]])
    }

    @Test func noActivityKeepsHerdrOrder() throws {
        let sections = try sections([:])
        #expect(sections.sorted(.recentActivity) == sections)
    }

    @Test func panesInsideATabKeepHerdrOrder() throws {
        let sorted = try sections([shell: start + 60, refactor: start]).sorted(.recentActivity)
        #expect(sorted[0].rows[0].panes.map(\.id) == [refactor, shell])
    }

    // MARK: The store

    @Test func theViewMenuChecksTheCurrentOrder() throws {
        let store = AppStore(
            herdUpdates: AsyncStream { $0.finish() }, transcripts: NoTranscripts(), control: FakeControl())
        #expect(store.isChecked(.sortPanes(.herdr)) == true)
        #expect(store.isChecked(.sortPanes(.recentActivity)) == false)
        store.perform(.sortPanes(.recentActivity))
        #expect(store.isChecked(.sortPanes(.herdr)) == false)
        #expect(store.isChecked(.sortPanes(.recentActivity)) == true)
        #expect(store.title(of: .sortPanes(.recentActivity)) == "Recent Activity")
        #expect(store.title(of: .sortPanes(.herdr)) == "Herdr Order")
    }

    @Test func sortingByActivityMovesAChangedPaneUpAndNextPaneFollows() throws {
        let clock = Clock()
        let store = AppStore(
            herdUpdates: AsyncStream { $0.finish() }, transcripts: NoTranscripts(), control: FakeControl(),
            now: { clock.time.withLock { $0 } })
        let herd = try herd()
        store.apply(.herd(herd))
        store.perform(.sortPanes(.recentActivity))
        #expect(store.sections.panes.map(\.id) == [refactor, shell, codex, scratch])

        clock.advance(by: 30)
        store.apply(.herd(changing(herd, codex) { $0.revision = 10 }))
        #expect(store.sections.panes.map(\.id) == [codex, refactor, shell, scratch])
        store.perform(.selectNextPane)
        #expect(store.selection == codex)

        store.perform(.sortPanes(.herdr))
        #expect(store.sections.panes.map(\.id) == [refactor, shell, codex, scratch])
    }

    @Test func thePinnedSectionKeepsPinOrder() throws {
        let clock = Clock()
        let store = AppStore(
            herdUpdates: AsyncStream { $0.finish() }, transcripts: NoTranscripts(), control: FakeControl(),
            now: { clock.time.withLock { $0 } })
        let herd = try herd()
        store.apply(.herd(herd))
        store.perform(.togglePin(refactor))
        store.perform(.togglePin(codex))
        store.perform(.sortPanes(.recentActivity))
        clock.advance(by: 30)
        store.apply(.herd(changing(herd, codex) { $0.revision = 10 }))
        #expect(store.sections[0].rows.map(\.id) == ["w1:p1", "w1:pB"])
        #expect(store.sections[1].rows.map(\.id) == ["w1:pB", "w1:t1"])
    }

    @Test func theOrderSurvivesARelaunch() throws {
        let notes = InMemoryPaneNotesStore()
        let store = AppStore(
            herdUpdates: AsyncStream { $0.finish() }, transcripts: NoTranscripts(), control: FakeControl(), notes: notes
        )
        store.perform(.sortPanes(.recentActivity))
        let data = try JSONEncoder().encode(notes.load())
        #expect(try JSONDecoder().decode(PaneNotes.self, from: data).order == .recentActivity)
    }

    @Test func notesSavedBeforeSortingLoadInHerdrOrder() throws {
        let data = Data(#"{"names":{},"pins":[]}"#.utf8)
        #expect(try JSONDecoder().decode(PaneNotes.self, from: data).order == .herdr)
    }

    @Test func anUnknownOrderLoadsAsHerdrOrder() throws {
        let data = Data(#"{"order":"alphabetical","pins":["w1:p1"]}"#.utf8)
        let notes = try JSONDecoder().decode(PaneNotes.self, from: data)
        #expect(notes.order == .herdr)
        #expect(notes.pins == [refactor])
    }
}
