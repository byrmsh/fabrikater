import Foundation
import Testing

@testable import TranscriptKit

struct ClaudeTranscriptParserTests {
    private func entries() throws -> [TranscriptEntry] {
        ClaudeTranscriptParser.parse(try Fixture.data(named: "claude.synthetic.jsonl"))
    }

    @Test func keepsSpeechAndDropsPlumbing() throws {
        let entries = try entries()
        #expect(entries.map(\.id) == ["u1", "a3", "a6", "u6", "u7", "u8", "u9", "u10", "a7"])
        #expect(
            entries.map(\.role) == [.user, .assistant, .assistant, .user, .user, .note, .note, .summary, .assistant])
    }

    @Test func groupsRowsOfOneResponseAndFoldsToolResults() throws {
        let entry = try entries()[1]
        #expect(
            entry.parts == [
                .text("I'll look at the helper first."),
                .tool(
                    ToolCall(
                        name: "Read", summary: "/home/user/project/helper.swift",
                        result: ToolResult(text: "func helper() {}"))),
            ])
    }

    @Test func summarisesTheCommandStripsANSIAndMarksErrors() throws {
        let entry = try entries()[2]
        #expect(
            entry.parts == [
                .tool(
                    ToolCall(
                        name: "Bash", summary: "swift test --parallel",
                        result: ToolResult(text: "error: 1 test failed", isError: true)))
            ])
    }

    @Test func keepsAResultWhoseCallWasNotRead() throws {
        #expect(
            try entries()[3].parts == [
                .tool(
                    ToolCall(
                        name: "result", summary: "", result: ToolResult(text: "output of a call before the window")))
            ])
    }

    @Test func classifiesCommandsAndNotes() throws {
        let entries = try entries()
        #expect(entries[4].parts == [.text("/model opus")])
        #expect(entries[5].parts == [.text("Set model to opus")])
        #expect(entries[6].parts == [.text("Background build finished")])
    }

    @Test func skipsAClippedFirstLineAndAPartialLastLine() throws {
        let text = String(decoding: try Fixture.data(named: "claude.synthetic.jsonl"), as: UTF8.self)
        let lastRow = try #require(text.range(of: #"{"type":"assistant","uuid":"a7""#)).lowerBound
        let clipped =
            text[text.index(text.startIndex, offsetBy: 40)..<lastRow] + #"{"type":"assistant","uuid":"a7","mess"#
        let entries = ClaudeTranscriptParser.parse(Data(clipped.utf8))
        #expect(entries.first?.id == "u1")
        #expect(entries.last?.id == "u10")
    }

    @Test func clampsLongTextInUTF16Units() {
        let (text, truncated) = TextRules.clamp(String(repeating: "a", count: 25), to: 20)
        #expect(text.count == 20 && truncated)
        #expect(TextRules.clamp("short", to: 20) == ("short", false))
    }

    @Test func summaryPrefersKnownKeysAndCapsLength() {
        #expect(TextRules.summarizeToolInput(["description": "d", "pattern": "p"]) == "p")
        #expect(TextRules.summarizeToolInput(["zeta": "z", "alpha": "a"]) == "a")
        #expect(TextRules.summarizeToolInput(["paths": ["a", "b"]]) == "a b")
        #expect(TextRules.summarizeToolInput(["command": String(repeating: "x", count: 300)]).count == 200)
    }
}
