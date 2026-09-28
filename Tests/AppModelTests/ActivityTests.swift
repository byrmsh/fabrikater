import FabrikaterCore
import Foundation
import HerdrKit
import Synchronization
import Testing
import TranscriptKit

@testable import AppModel

@MainActor
struct ActivityTests {
    private struct NoTranscripts: TranscriptService {
        func claudeTranscript(session: SessionID, bytes: Int) async throws -> Transcript { Transcript() }
    }

    private final class Clock: Sendable {
        let time = Mutex(Date(timeIntervalSince1970: 1_000_000))
        func advance(by seconds: TimeInterval) { time.withLock { $0 += seconds } }
    }

    private let refactor = PaneID("w1:p1")!
    private let shell = PaneID("w1:pA")!
    private let codex = PaneID("w1:pB")!
    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func herd() throws -> Herd {
        try Herd(snapshotReply: Fixture.data(named: "snapshot.synthetic.json"))
    }

    private func changing(_ herd: Herd, _ id: PaneID, _ change: (inout Herd.Pane) -> Void) -> Herd {
        var herd = herd
        if let index = herd.panes.firstIndex(where: { $0.id == id }) {
            change(&herd.panes[index])
        }
        return herd
    }

    private func row(_ id: PaneID, in store: AppStore) -> PaneRow? {
        store.sections.panes.first { $0.id == id }
    }

    // MARK: Change detection

    @Test func theFirstHerdStampsNothing() throws {
        let activity = PaneActivity().seeing(try herd(), at: start)
        #expect(activity.times.isEmpty)
    }

    @Test func anUnchangedHerdStampsNothing() throws {
        let herd = try herd()
        let activity = PaneActivity().seeing(herd, at: start).seeing(herd, at: start + 60)
        #expect(activity.times.isEmpty)
    }

    @Test func aStatusChangeStampsThatPaneOnly() throws {
        let herd = try herd()
        let changed = changing(herd, refactor) { $0.agentStatus = .done }
        let activity = PaneActivity().seeing(herd, at: start).seeing(changed, at: start + 60)
        #expect(activity.times == [refactor: start + 60])
    }

    @Test func aRevisionChangeStampsThePane() throws {
        let herd = try herd()
        let changed = changing(herd, shell) { $0.revision = ($0.revision ?? 0) + 1 }
        let activity = PaneActivity().seeing(herd, at: start).seeing(changed, at: start + 5)
        #expect(activity.times == [shell: start + 5])
    }

    @Test func theTimeStaysUntilTheNextChange() throws {
        let herd = try herd()
        let changed = changing(herd, refactor) { $0.agentStatus = .done }
        let activity = PaneActivity().seeing(herd, at: start).seeing(changed, at: start + 60)
            .seeing(changed, at: start + 600)
        #expect(activity.times == [refactor: start + 60])
        let again = activity.seeing(herd, at: start + 900)
        #expect(again.times == [refactor: start + 900])
    }

    @Test func aPaneThatLeavesIsForgottenAndStartsBlankWhenItReturns() throws {
        let herd = try herd()
        let changed = changing(herd, refactor) { $0.agentStatus = .done }
        var without = herd
        without.panes.removeAll { $0.id == refactor }
        let activity = PaneActivity().seeing(herd, at: start).seeing(changed, at: start + 60)
            .seeing(without, at: start + 120).seeing(herd, at: start + 180)
        #expect(activity.times.isEmpty)
    }

    @Test func theLaterSyntheticHerdChangesOnlyTheRefactorPane() throws {
        let later = try Herd(snapshotReply: Fixture.data(named: "snapshot-later.synthetic.json"))
        let activity = PaneActivity().seeing(try herd(), at: start).seeing(later, at: start + 20)
        #expect(activity.times == [refactor: start + 20])
    }

    // MARK: Formatting

    @Test(arguments: [
        (0, "now", "Active just now"),
        (59, "now", "Active just now"),
        (60, "1m", "Active 1 minute ago"),
        (119, "1m", "Active 1 minute ago"),
        (120, "2m", "Active 2 minutes ago"),
        (3599, "59m", "Active 59 minutes ago"),
        (3600, "1h", "Active 1 hour ago"),
        (86399, "23h", "Active 23 hours ago"),
        (86400, "1d", "Active 1 day ago"),
        (3 * 86400, "3d", "Active 3 days ago"),
        (-30, "now", "Active just now"),
    ])
    func formatsTheLargestWholeUnit(seconds: Int, short: String, spoken: String) {
        let text = ActivityText(since: start, now: start + TimeInterval(seconds))
        #expect(text.short == short)
        #expect(text.spoken == spoken)
    }

    // MARK: The sidebar

    @Test func rowsShowActivityOnceTheStoreSeesAChange() throws {
        let clock = Clock()
        let store = AppStore(
            herdUpdates: AsyncStream { $0.finish() }, transcripts: NoTranscripts(), control: FakeControl(),
            now: { clock.time.withLock { $0 } })
        let herd = try herd()
        store.apply(.herd(herd))
        #expect(row(refactor, in: store)?.lastActivity == nil)

        clock.advance(by: 30)
        store.apply(.herd(changing(herd, refactor) { $0.agentStatus = .done }))
        #expect(row(refactor, in: store)?.lastActivity == start + 30)
        #expect(row(codex, in: store)?.lastActivity == nil)
        #expect(row(refactor, in: store)?.activity(now: start + 30 + 180)?.short == "3m")
    }

    @Test func aTabRowTakesItsMostRecentPane() throws {
        let herd = try herd()
        let changed = changing(changing(herd, refactor) { $0.agentStatus = .done }, shell) { $0.revision = 99 }
        var activity = PaneActivity().seeing(herd, at: start)
        activity = activity.seeing(changing(herd, refactor) { $0.agentStatus = .done }, at: start + 10)
        activity = activity.seeing(changed, at: start + 20)
        let sections = SidebarSection.sections(for: changed).active(activity.times)
        guard case .tab(let tab) = sections[0].rows[0] else {
            Issue.record("w1:t1 is a tab")
            return
        }
        #expect(tab.panes.map(\.lastActivity) == [start + 10, start + 20])
        #expect(tab.lastActivity == start + 20)
    }

    @Test func aPinnedRowCarriesItsActivity() throws {
        let clock = Clock()
        let store = AppStore(
            herdUpdates: AsyncStream { $0.finish() }, transcripts: NoTranscripts(), control: FakeControl(),
            now: { clock.time.withLock { $0 } })
        let herd = try herd()
        store.apply(.herd(herd))
        store.perform(.togglePin(refactor))
        clock.advance(by: 30)
        store.apply(.herd(changing(herd, refactor) { $0.agentStatus = .done }))
        #expect(store.sections.first?.rows.first?.panes.first?.lastActivity == start + 30)
    }
}
