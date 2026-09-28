import AppModel
import Foundation
import Testing
import TranscriptKit

/// The highlighted tokens of `code`, without the plain ones, as `kind text` pairs.
private func marks(_ code: String, _ language: CodeLanguage) -> [String] {
    language.tokens(code).filter { $0.kind != .plain }.map { "\($0.kind) \($0.text)" }
}

@Suite struct HighlightingTests {
    @Test(arguments: [
        ("swift", CodeLanguage.swift), ("SH", .shell), ("bash", .shell), ("zsh", .shell), ("console", .shell),
        ("py", .python), ("python", .python), ("js", .javascript), ("tsx", .javascript), ("typescript", .javascript),
        ("json", .json), ("jsonc", .json), ("diff", .diff), ("patch", .diff),
    ])
    func fenceWordsNameTheirLanguage(fence: String, language: CodeLanguage) {
        #expect(CodeLanguage(fence: fence) == language)
    }

    @Test func unknownOrMissingFenceWordsAreNoLanguage() {
        #expect(CodeLanguage(fence: "") == nil)
        #expect(CodeLanguage(fence: "cobol") == nil)
        #expect(CodeLanguage.tokens("MOVE A TO B", fence: "cobol") == [CodeToken(.plain, "MOVE A TO B")])
    }

    @Test func filesTakeTheirLanguageFromTheExtension() {
        #expect(CodeLanguage(path: "/src/Sources/Uploader.swift") == .swift)
        #expect(CodeLanguage(path: "scripts/check.sh") == .shell)
        #expect(CodeLanguage(path: "web/app.test.ts") == .javascript)
        #expect(CodeLanguage(path: "Package.resolved") == nil)
        #expect(CodeLanguage(path: ".bashrc") == nil)
        #expect(CodeLanguage(path: "README") == nil)
    }

    @Test func aChangedFileIsHighlightedInItsLanguage() {
        #expect(FileChange(path: "/src/Uploader.swift", edits: []).language == .swift)
        #expect(FileChange(path: "/src/notes.txt", edits: []).language == nil)
    }

    @Test(arguments: CodeLanguage.allCases)
    func tokensJoinBackIntoTheCode(language: CodeLanguage) {
        let samples = [
            "let s = \"a \\\"quoted\\\" word\" // done\n/* open", "x = f'{a}' + \"\"\"\nmulti\n\"\"\"",
            "echo \"$HOME\" '${x}' # note\n", "{\"a\": [1, 2.5e3, true, null]}", "@@ -1 +1 @@\n-a\n+b\n",
            "unterminated \"string\nnext", "", "émoji 👩‍💻 \\",
        ]
        for sample in samples {
            let tokens = language.tokens(sample)
            #expect(tokens.map(\.text).joined() == sample)
            #expect(zip(tokens, tokens.dropFirst()).allSatisfy { $0.kind != $1.kind })
        }
    }

    @Test func swiftKeywordsTypesStringsCommentsAndAttributes() {
        let code = """
            @MainActor func load(_ id: Int) async throws -> String { // fetch
                let url = "https://x/\\(id)"
                #if os(macOS)
                return try await client.get(url, retries: 0x1F)
            }
            """
        #expect(
            marks(code, .swift) == [
                "attribute @MainActor", "keyword func", "type Int", "keyword async", "keyword throws", "type String",
                "comment // fetch", "keyword let", "string \"https://x/\\(id)\"", "attribute #if", "keyword return",
                "keyword try", "keyword await", "number 0x1F",
            ])
    }

    @Test func aRangeKeepsItsDotsOutOfTheNumbers() {
        #expect(marks("for attempt in 1...3 { }", .swift) == ["keyword for", "keyword in", "number 1", "number 3"])
        #expect(marks("let x = 2.5", .swift) == ["keyword let", "number 2.5"])
    }

    @Test func digitsInsideANameAreNotANumber() {
        #expect(marks("let md5 = sha256", .swift) == ["keyword let"])
    }

    @Test func swiftMultilineStringsAndBlockCommentsSpanLines() {
        #expect(marks("/* a\nb */ x", .swift) == ["comment /* a\nb */"])
        #expect(
            marks("let s = \"\"\"\nline \"one\"\n\"\"\"", .swift) == [
                "keyword let", "string \"\"\"\nline \"one\"\n\"\"\"",
            ])
    }

    @Test func anUnclosedStringStopsAtTheLineEnd() {
        #expect(marks("let s = \"open\nlet t", .swift) == ["keyword let", "string \"open", "keyword let"])
    }

    @Test func shellCommentsNeedASpaceBeforeTheHash() {
        #expect(
            marks("git log --oneline #recent\necho a#b", .shell) == ["comment #recent"])
    }

    @Test func shellVariablesAndQuotes() {
        #expect(
            marks("export PATH=\"$HOME/bin:${PATH}\"; echo $1 '$not' $?", .shell) == [
                "keyword export", "string \"$HOME/bin:${PATH}\"", "variable $1", "string '$not'", "variable $?",
            ])
    }

    @Test func shellWordsWithDashesAreNotKeywords() {
        #expect(marks("if-then done-list if", .shell) == ["keyword if"])
    }

    @Test func pythonPrefixedStringsDecoratorsAndBuiltinTypes() {
        let code = """
            @dataclass
            class Job(Base):
                def run(self, n: int) -> str:
                    return f"{n} done"  # ok
            """
        #expect(
            marks(code, .python) == [
                "attribute @dataclass", "keyword class", "type Job", "type Base", "keyword def", "keyword self",
                "type int", "type str", "keyword return", "string f\"{n} done\"", "comment # ok",
            ])
    }

    @Test func pythonTripleQuotedDocstrings() {
        #expect(marks("'''doc\nstring'''\nx = 1", .python) == ["string '''doc\nstring'''", "number 1"])
    }

    @Test func javascriptTemplatesTypesAndComments() {
        let code = "export const total = (items: Item[]): number => `${items.length}` /* n */ ?? null"
        #expect(
            marks(code, .javascript) == [
                "keyword export", "keyword const", "type Item", "type number", "string `${items.length}`",
                "comment /* n */", "keyword null",
            ])
    }

    @Test func jsonKeysReadApartFromStringValues() {
        #expect(
            marks("{\"name\" : \"fab\", \"n\": -1.5, \"ok\": false}", .json) == [
                "key \"name\"", "string \"fab\"", "key \"n\"", "number 1.5", "key \"ok\"", "keyword false",
            ])
    }

    @Test func diffLinesAndHeaders() {
        let code = "--- a/x.swift\n+++ b/x.swift\n@@ -1,2 +1,2 @@\n context\n-old\n+new\n+more"
        #expect(
            diffKinds(code) == [
                .meta, .meta, .meta, .plain, .removed, .added, .added,
            ])
        #expect(marks(code, .diff).last == "added +new\n+more")
    }

    @Test func codeOverTheLimitStaysPlain() {
        let code = String(repeating: "let a = 1\n", count: CodeLanguage.highlightLimit / 10 + 1)
        #expect(CodeLanguage.swift.tokens(code) == [CodeToken(.plain, code)])
    }

    @Test(arguments: [false, true])
    func everyColourReadsOnACodeBlock(dark: Bool) {
        // A code block's fill over the window background, and a diff line's added and removed tints over it.
        let backgrounds: [CodePalette.RGB] =
            dark
            ? [.init(0x343434), .init(0x2E3F30), .init(0x472523)] : [.init(0xE3E3E3), .init(0xDAF5E1), .init(0xFFE0DE)]
        for kind in CodeToken.Kind.allCases {
            guard let colour = CodePalette.color(for: kind, dark: dark) else { continue }
            for background in backgrounds {
                #expect(contrast(colour, background) >= 4.5, "\(kind) on \(background)")
            }
        }
    }
}

/// Each line's kind, as a diff's tokens say.
private func diffKinds(_ code: String) -> [CodeToken.Kind] {
    CodeLanguage.diff.tokens(code).flatMap { token in
        token.text.split(separator: "\n").map { _ in token.kind }
    }
}

/// WCAG's contrast ratio between two sRGB colours.
private func contrast(_ a: CodePalette.RGB, _ b: CodePalette.RGB) -> Double {
    func luminance(_ colour: CodePalette.RGB) -> Double {
        let channels = [colour.red, colour.green, colour.blue].map { value -> Double in
            let c = Double(value) / 255
            return c <= 0.039_28 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
    }
    let (high, low) = (max(luminance(a), luminance(b)), min(luminance(a), luminance(b)))
    return (high + 0.05) / (low + 0.05)
}
