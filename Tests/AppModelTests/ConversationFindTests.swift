import FabrikaterCore
import HerdrKit
import Testing
import TranscriptKit

@testable import AppModel

struct ConversationFindTests {
    private let entries = [
        TranscriptEntry(id: "u1", role: .user, parts: [.text("Rename the helper")]),
        TranscriptEntry(id: "a1", role: .assistant, parts: [.text("Looking at the code.")]),
        TranscriptEntry(
            id: "a2", role: .assistant,
            parts: [.tool(ToolCall(name: "Read", summary: "helper.swift", result: ToolResult(text: "tests")))]),
        TranscriptEntry(id: "a3", role: .assistant, parts: [.text("The HELPER is renamed; the café tests pass.")]),
    ]

    private func searching(_ query: String) -> ConversationFind {
        var find = ConversationFind()
        find.show()
        find.search(query, in: entries)
        return find
    }

    @Test func matchesTextAndToolLinesIgnoringCaseAndAccents() {
        #expect(searching("helper").matches == ["u1", "a2", "a3"])
        #expect(searching("cafe").matches == ["a3"])
        #expect(searching("read").matches == ["a2"])
    }

    @Test func toolResultsAreNotSearched() {
        #expect(searching("tests").matches == ["a3"])
    }

    @Test func theNewestMatchStartsCurrent() {
        let find = searching("helper")
        #expect(find.currentEntry == "a3")
        #expect(find.status == "3 of 3")
        #expect(find.highlight == "helper")
        #expect(find.isCurrent(entries[3]) && !find.isCurrent(entries[0]))
        #expect(find.highlight(for: entries[0]) == "helper")
        #expect(find.highlight(for: entries[1]) == nil)
    }

    @Test func stepsWrapAround() {
        var find = searching("helper")
        find.step(1)
        #expect(find.currentEntry == "u1")
        find.step(-1)
        find.step(-1)
        #expect(find.currentEntry == "a2")
        #expect(find.status == "2 of 3")
    }

    @Test func aBlankQueryFindsNothingAndSaysNothing() {
        let find = searching("  ")
        #expect(find.matches.isEmpty)
        #expect(find.status == nil)
        #expect(find.highlight == nil)
    }

    @Test func noMatchSaysNotFound() {
        let find = searching("zebra")
        #expect(find.status == "Not Found")
        #expect(find.currentEntry == nil)
    }

    @Test func hidingDropsTheHighlightButKeepsTheQuery() {
        var find = searching("helper")
        find.hide()
        #expect(find.highlight == nil)
        #expect(!find.reveals(entries[0]))
        #expect(find.query == "helper")
        find.step(1)
        #expect(find.isShown)
    }

    @Test func aRefreshKeepsTheCurrentMatch() {
        var find = searching("helper")
        find.step(1)
        let more = entries + [TranscriptEntry(id: "a4", role: .assistant, parts: [.text("helper done")])]
        find.refresh(more)
        #expect(find.matches == ["u1", "a2", "a3", "a4"])
        #expect(find.currentEntry == "u1")
        find.refresh(Array(entries.dropFirst()))
        #expect(find.currentEntry == "a3")
    }

    @Test func rangesDoNotOverlap() {
        let text = "aaaa Aá"
        let ranges = ConversationFind.ranges(of: "aa", in: text)
        #expect(ranges.map { String(text[$0]) } == ["aa", "aa", "Aá"])
        #expect(ConversationFind.ranges(of: "", in: text).isEmpty)
    }

    @Test func eachFindCommandHasItsShortcut() {
        #expect(Keymap.chord(for: .findInConversation) == KeyChord(.character("f")))
        #expect(Keymap.chord(for: .findNext) == KeyChord(.character("g")))
        #expect(Keymap.chord(for: .findPrevious) == KeyChord(.character("g"), [.command, .shift]))
    }
}

@MainActor
struct ConversationFindStoreTests {
    private struct FixedTranscripts: TranscriptService {
        let transcript: Transcript

        func transcript(of log: SessionLog, bytes: Int) async throws -> Transcript { transcript }
    }

    private static let long = (1...30).map { "line \($0)" }.joined(separator: "\n")

    private func makeStore(_ entries: [TranscriptEntry], isClipped: Bool = false) async throws -> AppStore {
        let store = AppStore(
            herdUpdates: AsyncStream { $0.finish() },
            transcripts: FixedTranscripts(transcript: Transcript(entries: entries, isClipped: isClipped)),
            control: FakeControl())
        store.apply(.herd(try Herd(snapshotReply: Fixture.data(named: "snapshot.synthetic.json"))))
        store.perform(.selectPane(PaneID("w2:p1")!))
        await store.conversation.loadTask?.value
        return store
    }

    @Test func findOpensTheBarAndStepsThroughMatches() async throws {
        let store = try await makeStore([
            TranscriptEntry(id: "u1", role: .user, parts: [.text("Rename the helper")]),
            TranscriptEntry(id: "a1", role: .assistant, parts: [.text("The helper is renamed.")]),
        ])
        #expect(store.isEnabled(.findInConversation))
        #expect(!store.isEnabled(.findNext))
        store.perform(.findInConversation)
        #expect(store.conversation.find.isShown)
        #expect(store.conversation.find.focusRequests == 1)
        store.perform(.searchConversation("helper"))
        #expect(store.conversation.find.currentEntry == "a1")
        #expect(store.isEnabled(.findPrevious))
        store.perform(.findPrevious)
        #expect(store.conversation.find.currentEntry == "u1")
        store.perform(.closeFind)
        #expect(!store.conversation.find.isShown)
        #expect(!store.isEnabled(.closeFind))
    }

    @Test func aCollapsedMatchShowsWhole() async throws {
        let summary = TranscriptEntry(id: "s1", role: .summary, parts: [.text("needle\n" + Self.long)])
        let store = try await makeStore([summary])
        #expect(store.conversation.isCollapsed(summary))
        store.perform(.findInConversation)
        store.perform(.searchConversation("needle"))
        #expect(!store.conversation.isCollapsed(summary))
        #expect(store.conversation.toggle(for: summary) == nil)
        store.perform(.closeFind)
        #expect(store.conversation.isCollapsed(summary))
        #expect(store.conversation.toggle(for: summary) == .expandEntry("s1"))
    }

    @Test func aClippedConversationOffersToSearchEarlier() async throws {
        let store = try await makeStore(
            [TranscriptEntry(id: "a1", role: .assistant, parts: [.text("latest")])], isClipped: true)
        #expect(!store.conversation.canFindEarlier)
        store.perform(.findInConversation)
        store.perform(.searchConversation("first"))
        #expect(store.conversation.canFindEarlier)
    }

    @Test func findIsOffWhileTheTerminalShows() async throws {
        let store = try await makeStore([TranscriptEntry(id: "a1", role: .assistant, parts: [.text("hello")])])
        store.perform(.toggleTerminal)
        #expect(!store.isEnabled(.findInConversation))
    }
}

/// The e2e `find` flow's numbers, from the conversation it shows.
struct ConversationFindFixtureTests {
    @Test func theSyntheticConversationHoldsHelperInThreeMessages() throws {
        let entries = ClaudeTranscriptParser.parse(try Fixture.data(named: "claude.synthetic.jsonl"))
        #expect(ConversationFind.matches(of: "helper", in: entries).count == 3)
    }
}
