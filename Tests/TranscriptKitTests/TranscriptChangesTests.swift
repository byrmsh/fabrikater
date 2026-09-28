import Foundation
import Testing

@testable import TranscriptKit

struct TranscriptChangesTests {
    private func changes(in lines: String...) -> [FileChange] {
        Transcript.changes(inClaudeLog: Data(lines.joined(separator: "\n").utf8))
    }

    private func edit(_ id: String, path: String = "/p/a.swift", old: String = "a", new: String = "b") -> String {
        """
        {"type":"assistant","message":{"content":[{"type":"tool_use","id":"\(id)","name":"Edit","input":{"file_path":"\(path)","old_string":"\(old)","new_string":"\(new)"}}]}}
        """
    }

    private func result(_ id: String, isError: Bool = false) -> String {
        """
        {"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"\(id)","is_error":\(isError),"content":"done"}]}}
        """
    }

    @Test func groupsByPathInFirstTouchedOrder() throws {
        let changes = Transcript.changes(inClaudeLog: try Fixture.data(named: "claude-changes.synthetic.jsonl"))
        #expect(
            changes.map(\.path) == [
                "/home/user/project/Sources/Uploader.swift", "/home/user/project/Tests/RetryTests.swift",
            ])
        #expect(changes.map(\.name) == ["Uploader.swift", "RetryTests.swift"])
        #expect(changes.first?.folder == "/home/user/project/Sources")
    }

    @Test func severalEditsToOneFileStayInOrder() throws {
        let uploader = try #require(
            Transcript.changes(inClaudeLog: try Fixture.data(named: "claude-changes.synthetic.jsonl")).first)
        #expect(uploader.edits.map(\.id) == ["toolu_1", "toolu_4-0", "toolu_4-1"])
        #expect(uploader.edits.map(\.kind) == [.edit, .edit, .edit])
        #expect(
            uploader.edits[1].lines == [DiffLine(.removed, "let attempts = 1"), DiffLine(.added, "let attempts = 3")])
        #expect(uploader.lineCounts == "+5 −3")
        #expect(uploader.spokenLineCounts == "5 lines added, 3 removed")
    }

    @Test func aWriteShowsTheNewContentAsAdded() throws {
        let tests = try #require(
            Transcript.changes(inClaudeLog: try Fixture.data(named: "claude-changes.synthetic.jsonl")).last)
        #expect(tests.edits.map(\.kind) == [.write])
        #expect(tests.edits.first?.lines.first == DiffLine(.added, "import Testing"))
        #expect(tests.edits.first?.lines.count == 5)
        #expect(tests.lineCounts == "+5")
        #expect(tests.spokenLineCounts == "5 lines added")
    }

    @Test func aFailedOrRejectedCallIsExcluded() {
        #expect(changes(in: edit("t1"), result("t1", isError: true)).isEmpty)
    }

    @Test func aCallWithoutAResultIsExcluded() {
        #expect(changes(in: edit("t1")).isEmpty)
        #expect(changes(in: result("t1"), edit("t1")).isEmpty)
    }

    @Test func subagentCallsAreSkipped() {
        let sidechain = edit("t1").replacingOccurrences(
            of: #"{"type":"assistant","#, with: #"{"type":"assistant","isSidechain":true,"#)
        #expect(changes(in: sidechain, result("t1")).isEmpty)
    }

    @Test func malformedInputChangesNothing() {
        let noPath =
            #"{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t1","name":"Edit","input":{"old_string":"a","new_string":"b"}}]}}"#
        #expect(changes(in: noPath, result("t1")).isEmpty)
    }

    @Test func aSessionWithoutEditsHasNoChanges() throws {
        #expect(Transcript.changes(inClaudeLog: try Fixture.data(named: "claude.synthetic.jsonl")).isEmpty)
    }

    @Test func diffKeepsUnchangedLinesAndPutsRemovalsFirst() {
        #expect(
            Transcript.diff(from: "a\nb\nc", to: "a\nB\nc\nd") == [
                DiffLine(.unchanged, "a"), DiffLine(.removed, "b"), DiffLine(.added, "B"), DiffLine(.unchanged, "c"),
                DiffLine(.added, "d"),
            ])
        #expect(Transcript.diff(from: "", to: "x\n") == [DiffLine(.added, "x")])
        #expect(Transcript.diff(from: "x", to: "") == [DiffLine(.removed, "x")])
    }

    @Test func aLongEditIsCutWithACount() throws {
        let content = (1...450).map { "line \($0)" }.joined(separator: "\n")
        let write = """
            {"type":"assistant","message":{"content":[{"type":"tool_use","id":"t1","name":"Write","input":{"file_path":"/p/big.txt","content":"\(content.replacingOccurrences(of: "\n", with: "\\n"))"}}]}}
            """
        let edit = try #require(changes(in: write, result("t1")).first?.edits.first)
        #expect(edit.lines.count == Transcript.diffLineLimit)
        #expect(edit.omittedLines == 50)
        #expect(edit.addedLines == 450)
        #expect(edit.omittedSummary == "50 more lines")
    }
}
