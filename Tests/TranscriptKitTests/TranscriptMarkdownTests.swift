import Testing

@testable import TranscriptKit

struct TranscriptMarkdownTests {
    private func entries() throws -> [TranscriptEntry] {
        ClaudeTranscriptParser.parse(try Fixture.data(named: "claude.synthetic.jsonl"))
    }

    @Test func rendersTheSyntheticConversation() throws {
        let markdown = Transcript.markdown(of: try entries())
        #expect(
            markdown == """
                ### User

                Rename the helper and run the tests

                ### Assistant

                I'll look at the helper first.

                **Read**

                ```
                /home/user/project/helper.swift
                ```

                ### Assistant

                **Bash** (failed)

                ```
                swift test --parallel
                ```

                ### User

                **result**

                ```
                output of a call before the window
                ```

                ### User

                /model opus

                ### Note

                > Set model to opus

                ### Note

                > Background build finished

                ### Summary

                > This session is being continued from a previous conversation.

                ### Assistant

                The helper is renamed and one test still fails.

                """)
    }

    @Test func aMessageHasNoHeading() throws {
        #expect(Transcript.markdownBody(of: try entries()[0]) == "Rename the helper and run the tests")
    }

    @Test func quotesEveryLineOfASummary() {
        let entry = TranscriptEntry(id: "s", role: .summary, parts: [.text("one\n\ntwo")])
        #expect(Transcript.markdownBody(of: entry) == "> one\n>\n> two")
    }

    @Test func aFenceOutgrowsBackticksInTheInput() {
        let call = ToolCall(name: "Bash", summary: "echo ```` done")
        let entry = TranscriptEntry(id: "t", role: .assistant, parts: [.tool(call)])
        #expect(Transcript.markdownBody(of: entry) == "**Bash**\n\n`````\necho ```` done\n`````")
    }

    @Test func marksClippedText() {
        let entry = TranscriptEntry(id: "c", role: .assistant, parts: [.text("long", truncated: true)])
        #expect(Transcript.markdownBody(of: entry) == "long…")
    }

    @Test func noEntriesIsEmpty() {
        #expect(Transcript.markdown(of: []) == "")
    }
}
