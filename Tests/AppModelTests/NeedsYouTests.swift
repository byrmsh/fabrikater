import FabrikaterCore
import Foundation
import HerdrKit
import Testing
import TranscriptKit

@testable import AppModel

@MainActor
struct NeedsYouTests {
    private struct NoTranscripts: TranscriptService {
        func transcript(of log: SessionLog, bytes: Int) async throws -> Transcript { Transcript() }
    }

    private let refactor = PaneID("w1:p1")!
    private let codex = PaneID("w1:pB")!
    private let scratch = PaneID("w2:p1")!

    private func makeStore(control: FakeControl = FakeControl()) throws -> (AppStore, Herd) {
        let herd = try Herd(snapshotReply: Fixture.data(named: "snapshot.synthetic.json"))
        let store = AppStore(herdUpdates: AsyncStream { $0.finish() }, transcripts: NoTranscripts(), control: control)
        store.apply(.herd(herd))
        return (store, herd)
    }

    private func setting(_ changes: [PaneID: AgentStatus], in herd: Herd) -> Herd {
        var herd = herd
        herd.panes = herd.panes.map { pane in
            var pane = pane
            pane.agentStatus = changes[pane.id] ?? pane.agentStatus
            return pane
        }
        return herd
    }

    private func listed(_ store: AppStore) -> [PaneID] { store.needsYou.panes.map(\.id) }

    @Test func blockedPanesAreListedFromTheStart() throws {
        let (store, _) = try makeStore()
        #expect(listed(store) == [codex])
        #expect(store.needsYou.badge == "1")
    }

    @Test func aFinishedTurnJoinsAfterTheBlockedPanes() throws {
        let (store, herd) = try makeStore()
        store.apply(.herd(setting([refactor: .done], in: herd)))
        #expect(listed(store) == [codex, refactor])
        #expect(store.needsYou.badge == "2")
    }

    @Test func eachGroupKeepsSidebarOrder() throws {
        let (store, herd) = try makeStore()
        let blocked = setting([refactor: .blocked, scratch: .working], in: herd)
        store.apply(.herd(blocked))
        #expect(listed(store) == [refactor, codex])
        store.apply(.herd(setting([refactor: .blocked, scratch: .done], in: herd)))
        #expect(listed(store) == [refactor, codex, scratch])
    }

    @Test func anUnreadPaneWorkingAgainWaitsForItsNextTurn() throws {
        let (store, herd) = try makeStore()
        store.apply(.herd(setting([refactor: .done], in: herd)))
        store.apply(.herd(herd))
        #expect(listed(store) == [codex])
        store.apply(.herd(setting([refactor: .idle], in: herd)))
        #expect(listed(store) == [codex, refactor])
    }

    @Test func openingAFinishedPaneTakesItOut() throws {
        let (store, herd) = try makeStore()
        store.apply(.herd(setting([refactor: .done], in: herd)))
        store.perform(.selectPane(refactor))
        #expect(listed(store) == [codex])
    }

    @Test func aBlockedPaneStaysWhileOpenAndLeavesWhenItMovesOn() throws {
        let (store, herd) = try makeStore()
        store.perform(.selectPane(codex))
        #expect(listed(store) == [codex])
        store.apply(.herd(setting([codex: .working], in: herd)))
        #expect(listed(store).isEmpty)
        #expect(store.needsYou.badge == nil)
    }

    @Test func hiddenPanesAreLeftOut() throws {
        let (store, _) = try makeStore()
        store.perform(.toggleHidden(codex))
        #expect(listed(store).isEmpty)
    }

    @Test func theGroupIsNotASidebarSectionSoNavigationIgnoresIt() throws {
        let (store, herd) = try makeStore()
        #expect(store.sections == SidebarSection.sections(for: herd))
        store.perform(.selectNextPane)
        #expect(store.selection == refactor)
    }

    @Test func numberKeysSelectInGroupOrderAndOnlySelect() async throws {
        let control = FakeControl()
        let (store, herd) = try makeStore(control: control)
        store.apply(.herd(setting([refactor: .done], in: herd)))
        #expect(store.isEnabled(.selectNeedsYou(2)))
        #expect(!store.isEnabled(.selectNeedsYou(3)))
        #expect(store.title(of: .selectNeedsYou(1)) == "codex")
        #expect(store.title(of: .selectNeedsYou(3)) == "Needs You 3")
        store.perform(.selectNeedsYou(2))
        #expect(store.selection == refactor)
        store.perform(.selectNeedsYou(3))
        #expect(store.selection == refactor)
        await store.focusTask?.value
        #expect(control.performed.joined().allSatisfy { !$0.typesIntoPane })
    }

    @Test func numberKeysAreBoundToCommandOneToNine() {
        for number in 1...9 {
            #expect(Keymap.chord(for: .selectNeedsYou(number)) == KeyChord(.character(Character(String(number)))))
        }
        #expect(Keymap.chord(for: .selectNeedsYou(10)) == nil)
    }
}
