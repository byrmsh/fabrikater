import Foundation
import Testing

@testable import TranscriptKit

/// Collie's `bridge/journal/opencode.test.ts` grammar cases, on the lines `HostCommand.openCodeRows` prints.
struct OpenCodeTranscriptParserTests {
    private func line(_ object: [String: Any]) -> String {
        String(decoding: try! JSONSerialization.data(withJSONObject: object, options: .sortedKeys), as: UTF8.self)
    }

    private func parse(_ lines: String...) -> [TranscriptEntry] {
        OpenCodeTranscriptParser.parse(Data(lines.joined(separator: "\n").utf8))
    }

    @Test func readsTheSyntheticV1Session() throws {
        let entries = OpenCodeTranscriptParser.parse(try Fixture.data(named: "opencode.synthetic.jsonl"))
        #expect(entries.map(\.id) == ["msg_0001", "msg_0002", "msg_0003"])
        #expect(entries.map(\.role) == [.user, .assistant, .assistant])
        #expect(entries[0].timestamp == "2026-09-21T14:13:20.000Z")
        #expect(
            entries[1].parts == [
                .text("I'll find every use of the flag."),
                .tool(
                    ToolCall(
                        name: "grep", summary: "--dry\\b", result: ToolResult(text: "src/cli.ts:14\nsrc/help.ts:3"))),
                .tool(
                    ToolCall(
                        name: "bash", summary: "npm run lint",
                        result: ToolResult(text: "lint failed: 2 problems", isError: true))),
            ])
        #expect(entries[2].parts.last == .tool(ToolCall(name: "edit", summary: "src/cli.ts")))
    }

    @Test func readsV2LinesWithTheRoleInTheirType() {
        let user = line(["id": "m1", "ts": 1, "type": "user", "data": ["text": "hello"]])
        let assistant = line([
            "id": "m2", "ts": 2, "type": "assistant",
            "data": [
                "content": [
                    ["type": "text", "text": "hi"],
                    [
                        "type": "tool", "name": "bash",
                        "state": [
                            "status": "completed", "input": ["command": "ls"],
                            "content": [["type": "text", "text": "a"]],
                        ],
                    ],
                ]
            ],
        ])
        let compaction = line(["id": "m3", "ts": 3, "type": "compaction", "data": ["summary": "## Objective"]])
        let failed = line([
            "id": "m4", "ts": 4, "type": "assistant", "data": ["content": [], "error": ["message": "rate limited"]],
        ])
        let plumbing = line(["id": "m5", "ts": 5, "type": "model-switched", "data": ["text": "x"]])
        let entries = parse(user, assistant, compaction, failed, plumbing)
        #expect(entries.map(\.role) == [.user, .assistant, .summary, .assistant])
        #expect(entries[1].parts[1] == .tool(ToolCall(name: "bash", summary: "ls", result: ToolResult(text: "a"))))
        #expect(entries[2].parts == [.text("## Objective")])
        #expect(entries[3].parts == [.text("rate limited")])
    }

    @Test func aMessagePrintedAgainReplacesItsEntryInPlace() {
        func message(_ id: String, _ text: String) -> String {
            line([
                "id": id, "ts": 1, "data": ["role": "assistant"],
                "parts": [["id": "p", "data": ["type": "text", "text": text]]],
            ])
        }
        let entries = parse(message("m1", "Work"), message("m2", "Next"), message("m1", "Working on it"))
        #expect(entries.map(\.id) == ["m1", "m2"])
        #expect(entries[0].parts == [.text("Working on it")])
    }

    @Test func unknownRolesBookkeepingAndClippedLinesRenderNothing() {
        let system = line(["id": "m1", "data": ["role": "system"], "parts": [["data": ["type": "text", "text": "x"]]]])
        let steps = line(["id": "m2", "data": ["role": "assistant"], "parts": [["data": ["type": "step-start"]]]])
        #expect(parse(#"s":[]}"#, system, steps, #"{"id":"m3","da"#).isEmpty)
    }
}
