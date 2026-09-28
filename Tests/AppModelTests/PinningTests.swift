import FabrikaterCore
import Foundation
import HerdrKit
import Testing
import TranscriptKit

@testable import AppModel

@MainActor
struct PinningTests {
    private struct NoTranscripts: TranscriptService {
        func transcript(of log: SessionLog, bytes: Int) async throws -> Transcript { Transcript() }
    }

    private let scratch = PaneID("w2:p1")!
    private let refactor = PaneID("w1:p1")!

    private func makeStore(_ notes: any PaneNotesStore = InMemoryPaneNotesStore()) throws -> (AppStore, Herd) {
        let herd = try Herd(snapshotReply: Fixture.data(named: "snapshot.synthetic.json"))
        let store = AppStore(
            herdUpdates: AsyncStream { $0.finish() }, transcripts: NoTranscripts(), control: FakeControl(), notes: notes
        )
        store.apply(.herd(herd))
        return (store, herd)
    }

    private func pinnedIDs(_ store: AppStore) -> [PaneID] {
        guard let first = store.sections.first, first.title == "Pinned" else { return [] }
        return first.rows.flatMap(\.panes).map(\.id)
    }

    @Test func nothingPinnedLeavesTheSidebarAsHerdrHasIt() throws {
        let (store, herd) = try makeStore()
        #expect(store.sections == SidebarSection.sections(for: herd))
    }

    @Test func thePinnedSectionFollowsPinOrderAndKeepsPanesInTheirWorkspace() throws {
        let (store, _) = try makeStore()
        store.perform(.togglePin(scratch))
        store.perform(.togglePin(refactor))
        #expect(pinnedIDs(store) == [scratch, refactor])
        let workspaces = store.sections.dropFirst().flatMap { $0.rows.flatMap(\.panes) }.map(\.id)
        #expect(workspaces.contains(scratch) && workspaces.contains(refactor))
    }

    @Test func unpinningRemovesThePaneAndTheEmptySection() throws {
        let (store, herd) = try makeStore()
        store.perform(.togglePin(scratch))
        store.perform(.togglePin(scratch))
        #expect(store.sections == SidebarSection.sections(for: herd))
    }

    @Test func aPinnedRowShowsTheLocalName() throws {
        let (store, _) = try makeStore()
        store.perform(.renamePane(scratch))
        store.perform(.commitRename(scratch, "Release notes"))
        store.perform(.togglePin(scratch))
        #expect(store.sections.first?.rows.first?.panes.first?.label == "Release notes")
    }

    @Test func aVanishedPinnedPaneLeavesTheSectionButStaysPinned() throws {
        let notes = InMemoryPaneNotesStore(PaneNotes(pins: [scratch, refactor]))
        var (store, herd) = try makeStore(notes)
        herd.panes.removeAll { $0.id == scratch }
        store.apply(.herd(herd))
        #expect(pinnedIDs(store) == [refactor])
        #expect(notes.load().pins == [scratch, refactor])
    }

    @Test func nextAndPreviousSkipThePinnedDuplicate() throws {
        let (store, _) = try makeStore()
        store.perform(.togglePin(scratch))
        let order = (0..<4).map { _ in
            store.perform(.selectNextPane)
            return store.selection?.rawValue
        }
        #expect(order == ["w2:p1", "w1:p1", "w1:pA", "w1:pB"])
        store.perform(.selectNextPane)
        #expect(store.selection == scratch)
        store.perform(.selectPreviousPane)
        #expect(store.selection?.rawValue == "w1:pB")
    }

    @Test func theSwitcherListsAPinnedPaneOnce() throws {
        let (store, _) = try makeStore()
        store.perform(.togglePin(scratch))
        store.perform(.openQuickSwitcher)
        let ids = store.switcher?.results.map(\.id) ?? []
        #expect(ids.filter { $0 == scratch }.count == 1)
    }

    @Test func pinWithoutAPaneActsOnTheSelectionAndTheTitleSaysWhatItWillDo() throws {
        let (store, _) = try makeStore()
        #expect(!store.isEnabled(.togglePin(nil)))
        store.perform(.selectPane(scratch))
        #expect(store.title(of: .togglePin(nil)) == "Pin")
        store.perform(.togglePin(nil))
        #expect(pinnedIDs(store) == [scratch])
        #expect(store.title(of: .togglePin(nil)) == "Unpin")
        #expect(store.title(of: .togglePin(refactor)) == "Pin")
    }

    @Test func pinsAreSavedAndLoadedAtLaunch() throws {
        let notes = InMemoryPaneNotesStore()
        let (store, _) = try makeStore(notes)
        store.perform(.togglePin(refactor))
        let (relaunched, _) = try makeStore(notes)
        #expect(pinnedIDs(relaunched) == [refactor])
    }

    @Test func notesWithoutAPinsFieldDecodeAndPinsRoundTrip() throws {
        let old = try JSONDecoder().decode(PaneNotes.self, from: Data(#"{"names":{"w2:p1":"Saved"}}"#.utf8))
        #expect(old == PaneNotes(names: [scratch: "Saved"]))
        let notes = PaneNotes(pins: [scratch, refactor])
        #expect(try JSONDecoder().decode(PaneNotes.self, from: JSONEncoder().encode(notes)) == notes)
    }
}
