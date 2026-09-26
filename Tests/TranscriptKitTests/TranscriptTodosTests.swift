import Foundation
import Testing

@testable import TranscriptKit

struct TranscriptTodosTests {
    private func todos(in lines: String...) -> [Todo] {
        Transcript.latestTodos(inClaudeLog: Data(lines.joined(separator: "\n").utf8))
    }

    private func todoWrite(_ input: String, sidechain: Bool = false) -> String {
        """
        {"type":"assistant","isSidechain":\(sidechain),"message":{"content":[{"type":"tool_use","name":"TodoWrite","input":\(input)}]}}
        """
    }

    @Test func theLatestCallWins() throws {
        let todos = Transcript.latestTodos(inClaudeLog: try Fixture.data(named: "claude-todos.synthetic.jsonl"))
        #expect(
            todos.map(\.content) == [
                "Read the uploader", "Add the retry", "Write the retry tests", "Run the full test suite",
            ])
        #expect(todos.map(\.status) == [.completed, .completed, .inProgress, .pending])
    }

    @Test func aSessionWithoutAPlanHasNone() throws {
        #expect(Transcript.latestTodos(inClaudeLog: try Fixture.data(named: "claude.synthetic.jsonl")).isEmpty)
    }

    @Test func malformedLatestInputYieldsNoListRatherThanAnOlderOne() {
        let older = todoWrite(#"{"todos":[{"content":"Old","status":"pending"}]}"#)
        #expect(todos(in: older, todoWrite(#"{"todos":"not a list"}"#)).isEmpty)
        #expect(todos(in: older, todoWrite(#"{"todos":[{"content":"New","status":"blocked"}]}"#)).isEmpty)
        #expect(todos(in: older, todoWrite(#"{"todos":[{"status":"pending"}]}"#)).isEmpty)
    }

    @Test func aClearedPlanIsEmpty() {
        #expect(
            todos(in: todoWrite(#"{"todos":[{"content":"Old","status":"pending"}]}"#), todoWrite(#"{"todos":[]}"#))
                .isEmpty)
    }

    @Test func subagentPlansAndHalfWrittenLinesAreSkipped() {
        let main = todoWrite(#"{"todos":[{"content":"Main","status":"pending"}]}"#)
        let sub = todoWrite(#"{"todos":[{"content":"Sub","status":"pending"}]}"#, sidechain: true)
        let halfWritten = #"{"type":"assistant","message":{"content":[{"type":"tool_use","name":"TodoWrite""#
        #expect(todos(in: main, sub, halfWritten).map(\.content) == ["Main"])
    }

    @Test func anInProgressItemShowsItsActiveForm() {
        #expect(Todo(content: "Run tests", activeForm: "Running tests", status: .inProgress).title == "Running tests")
        #expect(Todo(content: "Run tests", activeForm: "Running tests", status: .pending).title == "Run tests")
        #expect(Todo(content: "Run tests", status: .inProgress).title == "Run tests")
    }

    @Test func progressCountsCompletedItems() throws {
        let todos = Transcript.latestTodos(inClaudeLog: try Fixture.data(named: "claude-todos.synthetic.jsonl"))
        #expect(Todo.progress(of: todos) == "2 of 4 done")
        #expect(Todo.progress(of: []) == "0 of 0 done")
    }
}
