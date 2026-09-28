import Foundation
import Testing

@testable import TranscriptKit

struct SessionFactsTests {
    private func facts(_ rows: String...) -> SessionFacts {
        SessionFacts.claude(Data(rows.joined(separator: "\n").utf8))
    }

    @Test func readsTheLatestValuesFromTheFixture() throws {
        let facts = SessionFacts.claude(try Fixture.data(named: "claude-facts.synthetic.jsonl"))
        #expect(facts.model == "claude-opus-4-1-20250805")
        #expect(facts.workingDirectory == "/home/user/project")
        #expect(facts.gitBranch == "feature/facts")
        #expect(facts.firstSeen == SessionFacts.parseTimestamp("2026-09-26T09:15:00.000Z"))
        #expect(facts.contextTokens == 8 + 1200 + 83000)
    }

    @Test func isEmptyWhenNoRowCarriesAnyFact() throws {
        #expect(SessionFacts.claude(Data()).isEmpty)
        #expect(facts(#"{"type":"user","message":{"role":"user","content":"hi"}}"#).isEmpty)
    }

    @Test func takesEachFieldFromTheLatestRowThatHasIt() {
        let facts = facts(
            #"{"type":"assistant","cwd":"/a","gitBranch":"one","message":{"model":"m1","usage":{"input_tokens":10}}}"#,
            #"{"type":"user","gitBranch":"two","message":{"role":"user","content":"x"}}"#,
            #"{"type":"assistant","message":{"model":"m2"}}"#
        )
        #expect(facts.model == "m2")
        #expect(facts.workingDirectory == "/a")
        #expect(facts.gitBranch == "two")
        #expect(facts.contextTokens == 10)
    }

    @Test func skipsSidechainAndSyntheticRows() {
        let facts = facts(
            #"{"type":"assistant","cwd":"/main","message":{"model":"m1","usage":{"input_tokens":7}}}"#,
            #"{"type":"assistant","message":{"model":"<synthetic>","usage":{"input_tokens":0}}}"#,
            #"{"type":"assistant","isSidechain":true,"cwd":"/side","message":{"model":"sub","usage":{"input_tokens":99}}}"#
        )
        #expect(facts.model == "m1")
        #expect(facts.workingDirectory == "/main")
        #expect(facts.contextTokens == 7)
    }

    @Test func treatsEmptyStringsAsAbsent() {
        let facts = facts(
            #"{"type":"user","cwd":"/a","gitBranch":"main","message":{"content":"x"}}"#,
            #"{"type":"user","cwd":"","gitBranch":"","message":{"content":"y"}}"#
        )
        #expect(facts.workingDirectory == "/a")
        #expect(facts.gitBranch == "main")
    }

    @Test func firstSeenSkipsRowsWithoutATimestampAndClippedLines() {
        let facts = facts(
            #"ped","timestamp":"2026-01-01T00:00:00Z"}"#,
            #"{"type":"permission-mode"}"#,
            #"{"type":"user","timestamp":"2026-09-26T10:00:00Z"}"#,
            #"{"type":"user","timestamp":"2026-09-26T11:00:00.500Z"}"#
        )
        #expect(facts.firstSeen == SessionFacts.parseTimestamp("2026-09-26T10:00:00Z"))
        #expect(facts.firstSeen != nil)
    }

    @Test func contextIsInputPlusCacheTokens() {
        #expect(
            SessionFacts.contextTokens([
                "input_tokens": 3, "cache_creation_input_tokens": 40, "cache_read_input_tokens": 500,
                "output_tokens": 9000,
            ]) == 543)
        #expect(SessionFacts.contextTokens(["output_tokens": 5]) == nil)
    }

    @Test(arguments: [
        (0, "0 tokens"), (1, "1 token"), (999, "999 tokens"), (1000, "1k tokens"), (84_208, "84.2k tokens"),
        (999_949, "999.9k tokens"), (999_950, "1M tokens"), (1_250_000, "1.3M tokens"),
    ])
    func formatsTokenCounts(count: Int, text: String) {
        #expect(SessionFacts.formatTokens(count) == text)
    }
}
