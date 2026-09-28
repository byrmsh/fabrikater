import AppModel
import Testing
import TranscriptKit

@Suite struct MarkdownBlocksTests {
    @Test func plainTextIsOneParagraphKeepingItsLineBreaks() {
        #expect(
            MarkdownBlock.parse("Done. The **tests** pass\nand `swift build` is clean.") == [
                .paragraph("Done. The **tests** pass\nand `swift build` is clean.")
            ])
    }

    @Test func blankLinesSeparateParagraphs() {
        #expect(MarkdownBlock.parse("One.\n\n\nTwo.") == [.paragraph("One."), .paragraph("Two.")])
    }

    @Test func headingsTakeTheirLevelAndDropClosingHashes() {
        #expect(
            MarkdownBlock.parse("# Plan\n### Step `one` ##\nText") == [
                .heading(level: 1, text: "Plan"), .heading(level: 3, text: "Step `one`"), .paragraph("Text"),
            ])
    }

    @Test func aHashWithoutASpaceIsNotAHeading() {
        #expect(MarkdownBlock.parse("#hashtag and ####### seven") == [.paragraph("#hashtag and ####### seven")])
    }

    @Test func fencedCodeKeepsItsTextAndLanguage() {
        let text = "Run:\n```swift\nlet a = 1\n\n  // indented\n```\nAfter."
        #expect(
            MarkdownBlock.parse(text) == [
                .paragraph("Run:"), .code(language: "swift", text: "let a = 1\n\n  // indented"), .paragraph("After."),
            ])
    }

    @Test func markdownInsideCodeStaysCode() {
        #expect(
            MarkdownBlock.parse("~~~\n# not a heading\n- not a list\n```\n~~~") == [
                .code(language: "", text: "# not a heading\n- not a list\n```")
            ])
    }

    @Test func anUnclosedFenceRunsToTheEndOfAReplyStillBeingWritten() {
        #expect(MarkdownBlock.parse("```bash\nswift test") == [.code(language: "bash", text: "swift test")])
    }

    @Test func bulletsAndNestedItems() {
        let text = "- one\n- two\n  - two a\n    - deeper\n  - two b\n- three"
        #expect(
            MarkdownBlock.parse(text) == [
                .list([
                    ListItem(level: 0, marker: "•", text: "one"),
                    ListItem(level: 0, marker: "•", text: "two"),
                    ListItem(level: 1, marker: "•", text: "two a"),
                    ListItem(level: 2, marker: "•", text: "deeper"),
                    ListItem(level: 1, marker: "•", text: "two b"),
                    ListItem(level: 0, marker: "•", text: "three"),
                ])
            ])
    }

    @Test func orderedItemsCountFromTheirFirstNumberAtEachLevel() {
        let text = "3. three\n1. four\n   1. nested\n   1. nested two\n1. five"
        #expect(
            MarkdownBlock.parse(text) == [
                .list([
                    ListItem(level: 0, marker: "3.", text: "three"),
                    ListItem(level: 0, marker: "4.", text: "four"),
                    ListItem(level: 1, marker: "1.", text: "nested"),
                    ListItem(level: 1, marker: "2.", text: "nested two"),
                    ListItem(level: 0, marker: "5.", text: "five"),
                ])
            ])
    }

    @Test func taskItemsShowABox() {
        #expect(
            MarkdownBlock.parse("- [x] done\n- [ ] open") == [
                .list([ListItem(level: 0, marker: "☑", text: "done"), ListItem(level: 0, marker: "☐", text: "open")])
            ])
    }

    @Test func continuationLinesJoinTheirItem() {
        let text = "1. First\n   more of it\n\n   a second paragraph\n2. Second\n\nAfter the list."
        #expect(
            MarkdownBlock.parse(text) == [
                .list([
                    ListItem(level: 0, marker: "1.", text: "First\nmore of it\n\na second paragraph"),
                    ListItem(level: 0, marker: "2.", text: "Second"),
                ]),
                .paragraph("After the list."),
            ])
    }

    @Test func aLooseListStaysOneList() {
        #expect(
            MarkdownBlock.parse("- a\n\n- b") == [
                .list([ListItem(level: 0, marker: "•", text: "a"), ListItem(level: 0, marker: "•", text: "b")])
            ])
    }

    @Test func codeUnderAnItemIsItsOwnBlockAndTheListResumes() {
        let text = "1. Build:\n   ```\n   swift build\n   ```\n2. Test"
        #expect(
            MarkdownBlock.parse(text) == [
                .list([ListItem(level: 0, marker: "1.", text: "Build:")]),
                .code(language: "", text: "swift build"),
                .list([ListItem(level: 0, marker: "2.", text: "Test")]),
            ])
    }

    @Test func emphasisAtTheStartOfALineIsNotABulletOrARule() {
        #expect(
            MarkdownBlock.parse("**Bold** start\n*em* too\n+1 from me") == [
                .paragraph("**Bold** start\n*em* too\n+1 from me")
            ])
    }

    @Test func rules() {
        #expect(MarkdownBlock.parse("Above\n\n---\n* * *\n___") == [.paragraph("Above"), .rule, .rule, .rule])
    }

    @Test func quotesParseTheirOwnBlocks() {
        #expect(
            MarkdownBlock.parse("> Note\n> - a\n>\n> text\nAfter") == [
                .quote([.paragraph("Note"), .list([ListItem(level: 0, marker: "•", text: "a")]), .paragraph("text")]),
                .paragraph("After"),
            ])
    }

    @Test func tablesWithAlignmentsAndRaggedRows() {
        let text =
            "Results:\n| File | Lines | Status |\n|:-----|------:|:------:|\n| `a.swift` | 12 | ok |\n| b \\| c |\n\nDone."
        #expect(
            MarkdownBlock.parse(text) == [
                .paragraph("Results:"),
                .table(
                    MarkdownTable(
                        header: ["File", "Lines", "Status"],
                        alignments: [.leading, .trailing, .center],
                        rows: [["`a.swift`", "12", "ok"], ["b | c", "", ""]]
                    )
                ),
                .paragraph("Done."),
            ])
    }

    @Test func aPipeWithoutADelimiterRowIsText() {
        #expect(MarkdownBlock.parse("a | b\nc | d") == [.paragraph("a | b\nc | d")])
    }

    @Test func emptyTextHasNoBlocks() {
        #expect(MarkdownBlock.parse("").isEmpty)
        #expect(MarkdownBlock.parse("\n  \n").isEmpty)
    }

    @Test func theMarkdownFixturesReplyParsesIntoEveryKindOfBlock() throws {
        let entries = ClaudeTranscriptParser.parse(try Fixture.data(named: "claude-markdown.synthetic.jsonl"))
        guard case .text(let reply, _) = entries.last?.parts.first else {
            Issue.record("no reply text")
            return
        }
        let blocks = MarkdownBlock.parse(reply)
        #expect(blocks.first == .heading(level: 2, text: "Summary"))
        #expect(
            blocks.contains(
                .list([
                    ListItem(level: 0, marker: "1.", text: "Wrapped `upload()` in a retry loop"),
                    ListItem(level: 0, marker: "2.", text: "Added a backoff:"),
                    ListItem(level: 1, marker: "•", text: "1 s, then 2 s"),
                    ListItem(level: 1, marker: "•", text: "gives up after 3 tries"),
                    ListItem(level: 0, marker: "3.", text: "Covered it in `RetryTests`"),
                ])))
        #expect(blocks.contains(.code(language: "swift", text: "for attempt in 1...3 {\n    try await upload()\n}")))
        #expect(blocks.contains(.quote([.paragraph("The backoff is fixed for now.")])))
        #expect(blocks.contains(.rule))
        #expect(blocks.contains { if case .table(let table) = $0 { table.rows.count == 2 } else { false } })
        #expect(
            blocks.last
                == .list([
                    ListItem(level: 0, marker: "☑", text: "Retry"), ListItem(level: 0, marker: "☐", text: "Jitter"),
                ]))
    }
}
