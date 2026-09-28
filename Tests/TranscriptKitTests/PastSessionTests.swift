import FabrikaterCore
import Foundation
import HostKit
import Testing

@testable import TranscriptKit

struct PastSessionTests {
    private func sessions() throws -> [PastSession] {
        PastSession.parse(listing: try Fixture.data(named: "claude-sessions.synthetic.txt"), format: .claude)
    }

    @Test func listsTheSessionsNewestFirstWithTheirPrompts() throws {
        let sessions = try sessions()
        #expect(sessions.map { $0.id.rawValue.suffix(2) } == ["01", "a1", "a2", "a3"])
        #expect(
            sessions.map(\.title) == [
                "Rename the helper and run the tests", "Add a retry with backoff to the sync client",
                "Why does the settings screen flicker on launch?", "Write a README section on running locally",
            ])
        #expect(sessions.map(\.isCurrent) == [true, false, false, false])
        #expect(sessions[1].bytes == 1_245_184)
        #expect(sessions[1].modified == Date(timeIntervalSince1970: 1_790_410_000))
        #expect(sessions.allSatisfy { $0.log.format == .claude })
    }

    @Test func leavesOutALogWithoutAPromptUnlessItIsTheLiveOne() {
        let listing = Data(
            """
            00000000-0000-4000-8000-00000000000a.jsonl
            100\t10\t00000000-0000-4000-8000-00000000000a.jsonl
            90\t20\t00000000-0000-4000-8000-00000000000b.jsonl

            """.utf8)
        let sessions = PastSession.parse(listing: listing, format: .claude)
        #expect(sessions.map(\.id.rawValue) == ["00000000-0000-4000-8000-00000000000a"])
        #expect(sessions.first?.title == "")
    }

    @Test func skipsLinesThatAreNotASessionLog() {
        let listing = Data(
            """
            x.jsonl
            100\t10\tnotes.jsonl\t{"type":"user","message":{"content":"Hi"}}
            100\t10\t../00000000-0000-4000-8000-00000000000a.txt
            abc\t10\t00000000-0000-4000-8000-00000000000b.jsonl\t{"type":"user","message":{"content":"Hi"}}
            100\t10\t00000000-0000-4000-8000-00000000000c.jsonl\t{"type":"user","message":{"content":"Kept"}}

            """.utf8)
        #expect(PastSession.parse(listing: listing, format: .claude).map(\.title) == ["Kept"])
    }

    @Test func takesTheFirstCandidateThatHasAPrompt() {
        let row =
            #"100\#t10\#t00000000-0000-4000-8000-00000000000c.jsonl\#t"#
            + #"{"type":"user","message":{"content":[{"type":"image"}]}}\#t"#
            + #"{"type":"user","message":{"content":"Second"}}"#
        #expect(PastSession.parse(listing: Data("c\n\(row)\n".utf8), format: .claude).first?.title == "Second")
    }

    @Test func readsARowCutShortByTheListing() {
        let row = Data(
            #"{"type":"user","message":{"role":"user","content":"Fix the \"quoted\" tab\tand café 😀 bu"#.utf8)
        #expect(
            PastSession.title(ofRow: row[...], in: ListedSessions(.claude)) == "Fix the \"quoted\" tab and café 😀 bu")
    }

    @Test func readsTextFromACutRowWithBlocks() {
        let row = Data(#"{"type":"user","message":{"content":[{"type":"text","text":"Line one\nline two"#.utf8)
        #expect(PastSession.title(ofRow: row[...], in: ListedSessions(.claude)) == "Line one line two")
    }

    @Test func ignoresPromptsThatAreTags() {
        let row = Data(#"{"type":"user","message":{"content":"<command-name>/clear</command-name>"}}"#.utf8)
        #expect(PastSession.title(ofRow: row[...], in: ListedSessions(.claude)) == nil)
    }

    @Test func clampsALongPromptToOneLine() {
        let long = String(repeating: "word ", count: 100)
        let row = Data(#"{"type":"user","message":{"content":"\#(long)"}}"#.utf8)
        let title = PastSession.title(ofRow: row[...], in: ListedSessions(.claude))
        #expect(title?.count == 200)
        #expect(title?.hasSuffix("…") == true)
    }

    @Test func theServiceListsEachAgentsSessions() async throws {
        let service = HostTranscriptService(runner: ReplayRunner(directory: Fixture.directory))
        let claude = try #require(SessionID("00000000-0000-4000-8000-000000000001"))
        #expect(try await service.pastSessions(besides: SessionLog(format: .claude, session: claude)).count == 4)
        let codex = try #require(SessionID("00000000-0000-4000-8000-000000000003"))
        let sessions = try await service.pastSessions(besides: SessionLog(format: .codex, session: codex))
        #expect(sessions.map(\.title).first == "The date parser rejects ISO weeks. Fix it and run the tests.")
        #expect(sessions.allSatisfy { $0.log.format == .codex })
    }

    @Test func readsCodexRolloutsByTheirPromptAsTyped() {
        let listing = Data(
            """
            rollout-2026-09-27T10-00-00-00000000-0000-4000-8000-00000000000a.jsonl
            100\t10\trollout-2026-09-27T10-00-00-00000000-0000-4000-8000-00000000000a.jsonl\t\
            {"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"Fix it"}]}}
            90\t20\trollout-2026-09-26T09-00-00-00000000-0000-4000-8000-00000000000b.jsonl\t\
            {"type":"event_msg","payload":{"type":"user_message","message":"Why\\nnow?"}}
            80\t20\trollout-2026-09-26T08-00-00-00000000-0000-4000-8000-00000000000c.jsonl\t\
            {"type":"event_msg","payload":{"type":"user_message","message":"Cut sho

            """.utf8)
        let sessions = PastSession.parse(listing: listing, format: .codex)
        #expect(sessions.map(\.id.rawValue.last) == ["a", "b", "c"])
        #expect(sessions.map(\.title) == ["Fix it", "Why now?", "Cut sho"])
        #expect(sessions.map(\.isCurrent) == [true, false, false])
    }

    @Test func readsPiLogsByTheirFirstUserMessage() {
        let listing = Data(
            """
            2026-09-27T10-00-00-000Z_00000000-0000-4000-8000-00000000000a.jsonl
            100\t10\t2026-09-27T10-00-00-000Z_00000000-0000-4000-8000-00000000000a.jsonl\t\
            {"type":"message","id":"p1","message":{"role":"user","content":[{"type":"text","text":"Why retry?"}]}}
            90\t20\t2026-09-26T10-00-00-000Z_00000000-0000-4000-8000-00000000000b.jsonl\t\
            {"type":"message","id":"p1","message":{"role":"user","content":[{"type":"image"},{"type":"text","text":"Look

            """.utf8)
        let sessions = PastSession.parse(listing: listing, format: .pi)
        #expect(sessions.map(\.title) == ["Why retry?", "Look"])
        #expect(sessions.allSatisfy { $0.log.format == .pi })
    }

    @Test func readsOpenCodeSessionsByTheirTitle() {
        let listing = Data(
            """
            ses_0123456789abcdef
            1790000002\t4096\tses_0123456789abcdef\t{"title":"Rename the dry flag"}
            1789000000\t512\tses_fedcba9876543210\t{"title":"Earlier\\tthing"}
            1788000000\t512\tnot-an-id\t{"title":"Skipped"}

            """.utf8)
        let sessions = PastSession.parse(listing: listing, format: .opencode)
        #expect(sessions.map(\.id.rawValue) == ["ses_0123456789abcdef", "ses_fedcba9876543210"])
        #expect(sessions.map(\.title) == ["Rename the dry flag", "Earlier thing"])
        #expect(sessions.first?.bytes == 4096)
    }
}
