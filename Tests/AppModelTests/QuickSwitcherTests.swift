import FabrikaterCore
import HerdrKit
import Testing
import TranscriptKit

@testable import AppModel

struct QuickSwitcherRankingTests {
    private func item(_ label: String, location: String = "Work › tab", agent: String = "Claude") -> SwitcherItem {
        SwitcherItem(
            row: PaneRow(
                id: PaneID("w1:p" + label.filter { $0.isASCII && ($0.isLetter || $0.isNumber) })!, label: label,
                status: .idle),
            location: location, agent: agent)
    }

    private func labels(_ query: String, _ items: [SwitcherItem]) -> [String] {
        QuickSwitcher.rank(query: query, panes: items).map(\.row.label)
    }

    @Test func anEmptyQueryListsEverythingInSidebarOrder() {
        let items = [item("zeta"), item("alpha"), item("mid")]
        #expect(labels("", items) == ["zeta", "alpha", "mid"])
        #expect(labels("   ", items) == ["zeta", "alpha", "mid"])
    }

    @Test func noMatchGivesAnEmptyList() {
        #expect(labels("xyz", [item("alpha"), item("beta")]).isEmpty)
    }

    @Test func matchesASubsequenceIgnoringCase() {
        #expect(labels("SRF", [item("Synthetic refactor"), item("scratch")]) == ["Synthetic refactor"])
    }

    @Test func aPrefixOutranksAMatchInsideAWord() {
        #expect(labels("api", [item("rapid"), item("api server")]) == ["api server", "rapid"])
    }

    @Test func wordStartsOutrankScatteredLetters() {
        #expect(labels("rn", [item("barn owl"), item("release notes")]) == ["release notes", "barn owl"])
    }

    @Test func camelCaseHumpsCountAsWordStarts() {
        #expect(labels("qs", [item("questions"), item("QuickSwitcher")]).first == "QuickSwitcher")
    }

    @Test func matchesTheWorkspaceTabAndAgent() {
        let items = [
            item("one", location: "Backend › api"),
            item("two", location: "Frontend › web", agent: "Codex"),
        ]
        #expect(labels("frontend", items) == ["two"])
        #expect(labels("codex", items) == ["two"])
        #expect(labels("api", items) == ["one"])
    }

    @Test func tiesKeepSidebarOrder() {
        let items = [item("build a"), item("build b"), item("build c")]
        #expect(labels("build", items) == ["build a", "build b", "build c"])
    }

    @Test func spacesInTheQueryAreIgnored() {
        #expect(labels("rel not", [item("release notes"), item("other")]) == ["release notes"])
    }
}

@MainActor
struct QuickSwitcherStoreTests {
    private struct NoTranscripts: TranscriptService {
        func transcript(of log: SessionLog, bytes: Int) async throws -> Transcript { Transcript() }
    }

    private let refactor = PaneID("w1:p1")!
    private let shell = PaneID("w1:pA")!
    private let codex = PaneID("w1:pB")!
    private let scratch = PaneID("w2:p1")!

    private func makeStore(names: [PaneID: String] = [:]) throws -> AppStore {
        let herd = try Herd(snapshotReply: Fixture.data(named: "snapshot.synthetic.json"))
        let store = AppStore(
            herdUpdates: AsyncStream { $0.finish() }, transcripts: NoTranscripts(), control: FakeControl(),
            notes: InMemoryPaneNotesStore(PaneNotes(names: names)))
        store.apply(.herd(herd))
        return store
    }

    @Test func opensOverEveryPaneInSidebarOrder() throws {
        let store = try makeStore()
        store.perform(.openQuickSwitcher)
        let switcher = try #require(store.switcher)
        #expect(switcher.results.map(\.id) == [refactor, shell, codex, scratch])
        #expect(switcher.highlighted == refactor)
        #expect(switcher.results.first?.location == "Synthetic A › api")
        #expect(switcher.results[1].agent == "Shell")
    }

    @Test func matchesACustomName() throws {
        let store = try makeStore(names: [scratch: "Release notes"])
        store.perform(.openQuickSwitcher)
        store.perform(.searchQuickSwitcher("relnot"))
        #expect(store.switcher?.results.map(\.id) == [scratch])
        #expect(store.switcher?.highlighted == scratch)
    }

    @Test func returnSelectsTheHighlightedPaneAndCloses() throws {
        let store = try makeStore()
        store.perform(.openQuickSwitcher)
        store.perform(.searchQuickSwitcher("codex"))
        store.perform(.chooseQuickSwitcherResult(nil))
        #expect(store.selection == codex)
        #expect(store.switcher == nil)
    }

    @Test func theHighlightMovesAndStopsAtTheEnds() throws {
        let store = try makeStore()
        store.perform(.openQuickSwitcher)
        store.perform(.moveQuickSwitcherHighlight(-1))
        #expect(store.switcher?.highlighted == refactor)
        store.perform(.moveQuickSwitcherHighlight(2))
        #expect(store.switcher?.highlighted == codex)
        store.perform(.moveQuickSwitcherHighlight(5))
        #expect(store.switcher?.highlighted == scratch)
    }

    @Test func closingKeepsTheSelection() throws {
        let store = try makeStore()
        store.perform(.selectPane(shell))
        store.perform(.openQuickSwitcher)
        store.perform(.closeQuickSwitcher)
        #expect(store.switcher == nil)
        #expect(store.selection == shell)
    }

    @Test func noMatchSaysSoAndChoosesNothing() throws {
        let store = try makeStore()
        store.perform(.openQuickSwitcher)
        store.perform(.searchQuickSwitcher("qqqq"))
        #expect(store.switcher?.emptyMessage == "No Matching Panes")
        #expect(!store.isEnabled(.chooseQuickSwitcherResult(nil)))
        store.perform(.chooseQuickSwitcherResult(nil))
        #expect(store.selection == nil)
    }

    @Test func aNewHerdKeepsTheQueryAndHighlight() throws {
        let store = try makeStore()
        store.perform(.openQuickSwitcher)
        store.perform(.searchQuickSwitcher("s"))
        store.perform(.moveQuickSwitcherHighlight(1))
        let highlighted = store.switcher?.highlighted
        store.apply(.herd(try Herd(snapshotReply: Fixture.data(named: "snapshot.synthetic.json"))))
        #expect(store.switcher?.query == "s")
        #expect(store.switcher?.highlighted == highlighted)
    }

    @Test func cannotOpenWithoutPanes() {
        let store = AppStore(
            herdUpdates: AsyncStream { $0.finish() }, transcripts: NoTranscripts(), control: FakeControl())
        #expect(!store.isEnabled(.openQuickSwitcher))
    }
}
