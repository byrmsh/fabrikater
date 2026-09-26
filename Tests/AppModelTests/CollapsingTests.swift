import FabrikaterCore
import HerdrKit
import Testing
import TranscriptKit

@testable import AppModel

struct CollapsingTests {
    private func lines(_ count: Int) -> String {
        (1...count).map { "line \($0)" }.joined(separator: "\n")
    }

    private func entry(_ role: TranscriptEntry.Role, _ text: String, id: String = "e") -> TranscriptEntry {
        TranscriptEntry(id: id, role: role, parts: [.text(text)])
    }

    @Test func aPromptCollapsesPastTheThreshold() {
        #expect(!entry(.user, lines(Collapsing.promptLines)).isCollapsible)
        #expect(entry(.user, lines(Collapsing.promptLines + 1)).isCollapsible)
    }

    @Test func aSummaryCollapsesPastTheVisibleLines() {
        #expect(!entry(.summary, lines(Collapsing.visibleLines)).isCollapsible)
        #expect(entry(.summary, lines(Collapsing.visibleLines + 1)).isCollapsible)
    }

    @Test func assistantTextAndNotesNeverCollapse() {
        #expect(!entry(.assistant, lines(40)).isCollapsible)
        #expect(!entry(.note, lines(40)).isCollapsible)
    }

    @Test func aLongLineCountsAsTheLinesItWrapsOnto() {
        #expect(Collapsing.lineCount("") == 1)
        #expect(Collapsing.lineCount(String(repeating: "a", count: Collapsing.wrapWidth)) == 1)
        #expect(Collapsing.lineCount(String(repeating: "a", count: Collapsing.wrapWidth + 1)) == 2)
        #expect(entry(.user, String(repeating: "a", count: Collapsing.wrapWidth * 13)).isCollapsible)
    }

    @Test func toolCallsDoNotCount() {
        let call = TranscriptPart.tool(ToolCall(name: "Bash", summary: "ls"))
        let entry = TranscriptEntry(id: "e", role: .user, parts: Array(repeating: call, count: 20))
        #expect(!entry.isCollapsible)
    }

    @Test func aLongSummaryStartsCollapsedAndExpandsPerEntry() {
        let first = entry(.summary, lines(30), id: "s1")
        let second = entry(.summary, lines(30), id: "s2")
        let expansion = EntryExpansion()
        #expect(expansion.isCollapsed(first) && expansion.isCollapsed(second))
        let expanded = expansion.expanding("s1")
        #expect(!expanded.isCollapsed(first) && expanded.isCollapsed(second))
        #expect(expanded.collapsing("s1").isCollapsed(first))
    }

    @Test func aShortEntryIsNeverCollapsed() {
        let short = entry(.user, "Rename the helper")
        #expect(!EntryExpansion().isCollapsed(short))
        #expect(EntryExpansion().toggle(for: short) == nil)
    }

    @Test func theToggleShowsAllThenLess() {
        let long = entry(.user, lines(20), id: "u1")
        #expect(EntryExpansion().toggle(for: long) == .expandEntry("u1"))
        #expect(EntryExpansion().expanding("u1").toggle(for: long) == .collapseEntry("u1"))
    }

    @MainActor
    @Test func expansionResetsWhenAnotherPaneIsShown() async throws {
        let summary = entry(.summary, lines(30), id: "s1")
        let store = AppStore(
            herdUpdates: AsyncStream { $0.finish() },
            transcripts: FixedTranscripts(transcript: Transcript(entries: [summary])), control: FakeControl())
        store.apply(.herd(try Herd(snapshotReply: Fixture.data(named: "snapshot.synthetic.json"))))
        store.perform(.selectPane(PaneID("w2:p1")!))
        await store.conversation.loadTask?.value
        store.perform(.expandEntry("s1"))
        #expect(!store.conversation.expansion.isCollapsed(summary))
        store.perform(.collapseEntry("s1"))
        #expect(store.conversation.expansion.isCollapsed(summary))
        store.perform(.expandEntry("s1"))
        store.perform(.selectPane(nil))
        store.perform(.selectPane(PaneID("w2:p1")!))
        #expect(store.conversation.expansion.isCollapsed(summary))
    }

    private struct FixedTranscripts: TranscriptService {
        let transcript: Transcript

        func claudeTranscript(session: SessionID, bytes: Int) async throws -> Transcript { transcript }
    }
}
