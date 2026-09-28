import FabrikaterCore
import Foundation
import HerdrKit
import Testing
import TranscriptKit

@testable import AppModel

@MainActor
struct HidingTests {
    private struct NoTranscripts: TranscriptService {
        func transcript(of log: SessionLog, bytes: Int) async throws -> Transcript { Transcript() }
    }

    private let refactor = PaneID("w1:p1")!
    private let shell = PaneID("w1:pA")!
    private let codex = PaneID("w1:pB")!
    private let scratch = PaneID("w2:p1")!

    private func makeStore(_ notes: any PaneNotesStore = InMemoryPaneNotesStore()) throws -> (AppStore, Herd) {
        let herd = try Herd(snapshotReply: Fixture.data(named: "snapshot.synthetic.json"))
        let store = AppStore(
            herdUpdates: AsyncStream { $0.finish() }, transcripts: NoTranscripts(), control: FakeControl(), notes: notes
        )
        store.apply(.herd(herd))
        return (store, herd)
    }

    private func paneIDs(_ store: AppStore) -> [PaneID] {
        store.sections.panes.map(\.id)
    }

    @Test func nothingHiddenLeavesTheSidebarAsHerdrHasIt() throws {
        let (store, herd) = try makeStore()
        #expect(store.sections == SidebarSection.sections(for: herd))
    }

    @Test func aHiddenPaneDropsOutAndItsTabCollapsesToTheOtherPane() throws {
        let (store, _) = try makeStore()
        store.perform(.toggleHidden(shell))
        #expect(paneIDs(store) == [refactor, codex, scratch])
        #expect(store.sections.first?.rows.first == .pane(store.sections.panes[0]))
    }

    @Test func showHiddenBringsHiddenPanesBackMarked() throws {
        let (store, _) = try makeStore()
        store.perform(.toggleHidden(codex))
        store.perform(.toggleShowHidden)
        #expect(store.isChecked(.toggleShowHidden) == true)
        #expect(paneIDs(store) == [refactor, shell, codex, scratch])
        let hidden = store.sections.panes.filter(\.isHidden).map(\.id)
        #expect(hidden == [codex])
        #expect(store.sections.panes.first { $0.id == codex }?.spokenLabel.hasSuffix(", Hidden") == true)
    }

    @Test func unhidingShowsThePaneAgain() throws {
        let (store, herd) = try makeStore()
        store.perform(.toggleHidden(codex))
        #expect(store.title(of: .toggleHidden(codex)) == "Unhide Pane")
        store.perform(.toggleHidden(codex))
        #expect(store.title(of: .toggleHidden(codex)) == "Hide Pane")
        #expect(store.sections == SidebarSection.sections(for: herd))
    }

    @Test func aHiddenWorkspaceDropsOutAndShowHiddenMarksItsHeading() throws {
        let (store, _) = try makeStore()
        store.perform(.toggleHiddenWorkspace("w2"))
        #expect(store.sections.map(\.id) == ["w1"])
        #expect(store.title(of: .toggleHiddenWorkspace("w2")) == "Unhide Workspace")
        store.perform(.toggleShowHidden)
        #expect(store.sections.map(\.heading) == ["Synthetic A", "fabrikater-test (Hidden)"])
    }

    @Test func hideWorkspaceWithoutAnIDActsOnTheSelectedPanesWorkspace() throws {
        let (store, _) = try makeStore()
        #expect(!store.isEnabled(.toggleHiddenWorkspace(nil)))
        store.perform(.selectPane(scratch))
        store.perform(.toggleHiddenWorkspace(nil))
        #expect(store.sections.map(\.id) == ["w1"])
        #expect(store.selection == scratch)
        #expect(store.title(of: .toggleHiddenWorkspace(nil)) == "Unhide Workspace")
    }

    @Test func onlyWorkspacesCanBeHidden() throws {
        let (store, _) = try makeStore()
        store.perform(.togglePin(scratch))
        #expect(store.isEnabled(.toggleHiddenWorkspace("w1")))
        #expect(!store.isEnabled(.toggleHiddenWorkspace("fabrikater.pinned")))
    }

    @Test func turningShellsOffLeavesOutPanesWithoutAnAgent() throws {
        let (store, herd) = try makeStore()
        #expect(store.isChecked(.toggleShowShells) == true)
        store.perform(.toggleShowShells)
        #expect(store.isChecked(.toggleShowShells) == false)
        #expect(paneIDs(store) == [refactor, codex, scratch])
        store.perform(.toggleShowShells)
        #expect(store.sections == SidebarSection.sections(for: herd))
    }

    @Test func aWorkspaceThatFilteringEmptiesDropsOut() throws {
        let (store, _) = try makeStore()
        store.perform(.toggleHidden(scratch))
        #expect(store.sections.map(\.id) == ["w1"])
    }

    @Test func aSelectedPaneThatBecomesHiddenStaysSelected() throws {
        let (store, _) = try makeStore()
        store.perform(.selectPane(codex))
        store.perform(.toggleHidden(nil))
        #expect(store.selection == codex)
        #expect(store.header?.title == "codex")
        #expect(!paneIDs(store).contains(codex))
    }

    @Test func aHiddenPinnedPaneLeavesThePinnedSection() throws {
        let (store, _) = try makeStore()
        store.perform(.togglePin(scratch))
        store.perform(.toggleHidden(scratch))
        #expect(store.sections.map(\.title) == ["Synthetic A"])
    }

    @Test func nextAndPreviousSkipHiddenPanes() throws {
        let (store, _) = try makeStore()
        store.perform(.toggleHidden(shell))
        let order = (0..<3).map { _ in
            store.perform(.selectNextPane)
            return store.selection
        }
        #expect(order == [refactor, codex, scratch])
    }

    @Test func hidingEverythingSaysSoInsteadOfNoWorkspaces() throws {
        let (store, _) = try makeStore()
        store.perform(.toggleHiddenWorkspace("w1"))
        store.perform(.toggleHiddenWorkspace("w2"))
        #expect(store.sections.isEmpty)
        #expect(store.emptySidebar.title == "Everything Is Hidden")
    }

    @Test func hidingIsSavedAndLoadedAtLaunch() throws {
        let notes = InMemoryPaneNotesStore()
        let (store, _) = try makeStore(notes)
        store.perform(.toggleHidden(codex))
        store.perform(.toggleShowShells)
        let (relaunched, _) = try makeStore(notes)
        #expect(paneIDs(relaunched) == [refactor, scratch])
    }

    @Test func notesWithoutAHidingFieldDecodeAndHidingRoundTrips() throws {
        let old = try JSONDecoder().decode(PaneNotes.self, from: Data(#"{"names":{},"pins":["w2:p1"]}"#.utf8))
        #expect(old == PaneNotes(pins: [scratch]))
        let notes = PaneNotes(
            hiding: Hiding(panes: [codex, shell], workspaces: ["w2"], showHidden: true, showShells: false))
        #expect(try JSONDecoder().decode(PaneNotes.self, from: JSONEncoder().encode(notes)) == notes)
    }
}
