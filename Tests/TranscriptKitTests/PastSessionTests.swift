import FabrikaterCore
import Foundation
import HostKit
import Testing

@testable import TranscriptKit

struct PastSessionTests {
    private func sessions() throws -> [PastSession] {
        PastSession.parse(listing: try Fixture.data(named: "claude-sessions.synthetic.txt"))
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
        let sessions = PastSession.parse(listing: listing)
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
        #expect(PastSession.parse(listing: listing).map(\.title) == ["Kept"])
    }

    @Test func takesTheFirstCandidateThatHasAPrompt() {
        let row =
            #"100\#t10\#t00000000-0000-4000-8000-00000000000c.jsonl\#t"#
            + #"{"type":"user","message":{"content":[{"type":"image"}]}}\#t"#
            + #"{"type":"user","message":{"content":"Second"}}"#
        #expect(PastSession.parse(listing: Data("c\n\(row)\n".utf8)).first?.title == "Second")
    }

    @Test func readsARowCutShortByTheListing() {
        let row = Data(
            #"{"type":"user","message":{"role":"user","content":"Fix the \"quoted\" tab\tand café 😀 bu"#.utf8)
        #expect(PastSession.title(ofUserRow: row[...]) == "Fix the \"quoted\" tab and café 😀 bu")
    }

    @Test func readsTextFromACutRowWithBlocks() {
        let row = Data(#"{"type":"user","message":{"content":[{"type":"text","text":"Line one\nline two"#.utf8)
        #expect(PastSession.title(ofUserRow: row[...]) == "Line one line two")
    }

    @Test func ignoresPromptsThatAreTags() {
        let row = Data(#"{"type":"user","message":{"content":"<command-name>/clear</command-name>"}}"#.utf8)
        #expect(PastSession.title(ofUserRow: row[...]) == nil)
    }

    @Test func clampsALongPromptToOneLine() {
        let long = String(repeating: "word ", count: 100)
        let row = Data(#"{"type":"user","message":{"content":"\#(long)"}}"#.utf8)
        let title = PastSession.title(ofUserRow: row[...])
        #expect(title?.count == 200)
        #expect(title?.hasSuffix("…") == true)
    }

    @Test func theServiceListsClaudeSessionsOnly() async throws {
        let service = HostTranscriptService(runner: ReplayRunner(directory: Fixture.directory))
        let session = try #require(SessionID("00000000-0000-4000-8000-000000000001"))
        #expect(try await service.pastSessions(besides: SessionLog(format: .claude, session: session)).count == 4)
        #expect(try await service.pastSessions(besides: SessionLog(format: .codex, session: session)).isEmpty)
    }
}
