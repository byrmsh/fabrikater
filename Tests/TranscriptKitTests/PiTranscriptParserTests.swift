import Foundation
import Testing

@testable import TranscriptKit

/// Collie's `bridge/journal/pi.test.ts` cases for the text the app shows, plus the synthetic session.
struct PiTranscriptParserTests {
    private func row(_ id: String, _ message: [String: Any]) -> String {
        let row: [String: Any] = [
            "type": "message", "id": id, "timestamp": "2026-09-27T10:00:00.000Z", "message": message,
        ]
        return String(decoding: try! JSONSerialization.data(withJSONObject: row, options: .sortedKeys), as: UTF8.self)
    }

    private func parse(_ lines: String...) -> [TranscriptEntry] {
        PiTranscriptParser.parse(Data(lines.joined(separator: "\n").utf8))
    }

    @Test func readsTheSyntheticSession() throws {
        let entries = PiTranscriptParser.parse(try Fixture.data(named: "pi.synthetic.jsonl"))
        #expect(entries.map(\.id) == ["p1", "p2", "p4", "p6"])
        #expect(entries.map(\.role) == [.user, .assistant, .assistant, .assistant])
        #expect(entries[0].parts == [.text("Why does the upload retry forever?")])
        #expect(
            entries[1].parts == [
                .text("Let me read the retry loop."),
                .tool(
                    ToolCall(
                        name: "read", summary: "src/upload.ts",
                        result: ToolResult(text: "while (true) {\n  await send()\n}"))),
            ])
        #expect(
            entries[2].parts == [
                .tool(
                    ToolCall(
                        name: "bash", summary: "npm test -- upload",
                        result: ToolResult(text: "1 failing: gives up after 5 tries", isError: true)))
            ])
    }

    @Test func bookkeepingRowsRenderNothing() {
        let session = #"{"type":"session","version":3,"id":"x","cwd":"/repo"}"#
        let change = #"{"type":"thinking_level_change","id":"t","thinkingLevel":"high"}"#
        let custom = #"{"type":"custom_message","id":"c","content":"x"}"#
        #expect(parse(session, change, custom).isEmpty)
    }

    @Test func anOrphanResultKeepsItsToolName() {
        let result = row(
            "r1",
            [
                "role": "toolResult", "toolCallId": "gone", "toolName": "bash",
                "content": [["type": "text", "text": "ok"]],
            ])
        #expect(parse(result)[0].parts == [.tool(ToolCall(name: "bash", summary: "", result: ToolResult(text: "ok")))])
    }

    @Test func aRowWithOnlyThinkingOrAnImageRendersNothing() {
        let thinking = row("a1", ["role": "assistant", "content": [["type": "thinking", "thinking": "**Plan**"]]])
        let image = row(
            "u1", ["role": "user", "content": [["type": "image", "data": "iVBORw0KGgo=", "mimeType": "image/png"]]])
        #expect(parse(thinking, image).isEmpty)
    }

    @Test func aClippedFirstLineIsSkippedAndARowWithoutAnIDGetsItsLine() {
        let entries = parse(
            #"sage","id":"x"}"#,
            #"{"type":"message","message":{"role":"user","content":[{"type":"text","text":"hi"}]}}"#)
        #expect(entries.map(\.id) == ["line-2"])
    }
}
