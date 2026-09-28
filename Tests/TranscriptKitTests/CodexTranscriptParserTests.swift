import Foundation
import Testing

@testable import TranscriptKit

/// Collie's `bridge/journal/codex.test.ts` cases, plus the synthetic rollout.
struct CodexTranscriptParserTests {
    private func item(_ payload: [String: Any], at second: Int = 0) -> String {
        let row: [String: Any] = [
            "timestamp": "2026-09-27T10:00:0\(second).000Z", "type": "response_item", "payload": payload,
        ]
        return String(decoding: try! JSONSerialization.data(withJSONObject: row, options: .sortedKeys), as: UTF8.self)
    }

    private func message(_ role: String, _ text: String) -> String {
        item(["type": "message", "role": role, "content": [["type": "input_text", "text": text]]])
    }

    private func call(_ id: String, arguments: String = "{}") -> String {
        item(["type": "function_call", "name": "shell", "arguments": arguments, "call_id": id])
    }

    private func parse(_ lines: String...) -> [TranscriptEntry] {
        CodexTranscriptParser.parse(Data(lines.joined(separator: "\n").utf8))
    }

    @Test func readsTheSyntheticRollout() throws {
        let entries = CodexTranscriptParser.parse(try Fixture.data(named: "codex.synthetic.jsonl"))
        #expect(entries.map(\.role) == [.user, .assistant, .assistant])
        #expect(entries[0].parts == [.text("The date parser rejects ISO weeks. Fix it and run the tests.")])
        #expect(entries[0].timestamp == "2026-09-27T10:00:02.000Z")
        #expect(
            entries[1].parts == [
                .text("I'll find where dates are parsed first."),
                .tool(
                    ToolCall(
                        name: "shell", summary: "bash -lc rg -n 'parseDate' src",
                        result: ToolResult(text: "src/dates.ts:12:export function parseDate(text: string) {\n"))),
                .tool(
                    ToolCall(
                        name: "apply_patch", summary: "src/dates.ts",
                        result: ToolResult(text: "Success. Updated the following files:\nM src/dates.ts\n"))),
                .tool(ToolCall(name: "shell", summary: "bash -lc npm test", result: ToolResult(text: "42 passing\n"))),
            ])
        #expect(entries[2].parts == [.text("ISO week dates like `2026-W39` now parse, and all **42** tests pass.")])
    }

    @Test func dropsTheEventFamilyWhichRepeatsEveryTurn() {
        let event = #"{"timestamp":"2026","type":"event_msg","payload":{"type":"user_message","message":"fix"}}"#
        #expect(parse(message("user", "fix"), event).count == 1)
    }

    @Test(arguments: ["developer", "system", "tool"])
    func otherRolesArePlumbing(role: String) {
        #expect(parse(message(role, "<permissions instructions>…")).isEmpty)
    }

    @Test func bookkeepingAndReasoningRenderNothing() {
        let meta = #"{"timestamp":"2026","type":"session_meta","payload":{"id":"x","cwd":"/repo"}}"#
        let reasoning = item(["type": "reasoning", "summary": [["type": "summary_text", "text": "**Thinking**"]]])
        #expect(parse(meta, item(["type": "world_state", "state": [:]]), reasoning).isEmpty)
    }

    @Test func malformedArgumentsStillSummarise() throws {
        let part = try #require(parse(call("c", arguments: #"{"command": ["bash""#)).first?.parts.first)
        guard case .tool(let tool) = part else {
            Issue.record("not a tool")
            return
        }
        #expect(tool.summary == #"{"command": ["bash""#)
    }

    @Test func anOutputFoldsOntoItsCallAndAnOrphanIsKept() {
        let output = item([
            "type": "function_call_output", "call_id": "call_1", "output": #"{"output":"total 0\n","metadata":{}}"#,
        ])
        let entries = parse(call("call_1"), output)
        #expect(entries.count == 1)
        #expect(
            entries[0].parts == [.tool(ToolCall(name: "shell", summary: "", result: ToolResult(text: "total 0\n")))])

        let orphan = item(["type": "function_call_output", "call_id": "gone", "output": #"{"output":"stranded"}"#])
        #expect(
            parse(orphan)[0].parts == [
                .tool(ToolCall(name: "result", summary: "", result: ToolResult(text: "stranded")))
            ])
    }

    @Test func injectedContextIsNotSomethingTheUserSaid() {
        let entries = parse(
            message("user", "<environment_context>\n  <cwd>/repo</cwd>\n</environment_context>"),
            message("user", "help me fix the types"))
        #expect(entries.map(\.parts) == [[.text("help me fix the types")]])
    }

    @Test func aClippedFirstLineAndAPartialLastLineAreSkipped() {
        #expect(
            parse(#"ponse_item","payload":{}}"#, message("user", "hi"), #"{"timestamp":"2026","type":"resp"#).count == 1
        )
    }

    @Test func identicalRowsGetDistinctStableIDs() {
        let entries = parse(message("user", "again"), message("user", "again"))
        #expect(entries.count == 2)
        #expect(entries[0].id != entries[1].id)
        #expect(entries[0].id.hasPrefix("cx-"))
        // An id depends on the row, not its position, so a window that starts elsewhere keeps it.
        #expect(parse(message("user", "first"), message("user", "again"))[1].id == entries[0].id)
    }

    @Test(arguments: [
        (#"{"output":"hello","metadata":{}}"#, "hello"), ("plain text", "plain text"),
        (#"{"other":1}"#, #"{"other":1}"#),
    ])
    func unwrapsTheOutputEnvelope(raw: String, output: String) {
        #expect(CodexTranscriptParser.output(raw) == output)
    }
}
