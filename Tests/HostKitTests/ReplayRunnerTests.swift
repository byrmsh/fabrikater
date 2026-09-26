import FabrikaterCore
import Foundation
import Testing

@testable import HostKit

struct ReplayRunnerTests {
    private let runner = ReplayRunner(directory: Fixture.directory)

    @Test func servesTheCapturedSnapshot() async throws {
        let data = try await runner.run(.herdrSnapshot)
        #expect(data == (try Fixture.data(named: "snapshot.json")))
    }

    @Test func servesTheTailOfTheSyntheticClaudeLog() async throws {
        let session = try #require(SessionID("00000000-0000-4000-8000-000000000001"))
        let data = try await runner.run(.claudeLogTail(session: session, bytes: 100))
        #expect(data == (try Fixture.data(named: "claude.synthetic.jsonl")).suffix(100))
    }

    @Test func streamsTheEventFixtureLineByLine() async throws {
        var lines: [String] = []
        for try await line in runner.lines(.herdrEvents, input: nil) {
            lines.append(line)
            if lines.count == 3 { break }
        }
        #expect(lines.first == #"{"id":"sub1","result":{"type":"subscription_started"}}"#)
    }

    @Test func failsWithoutAFixture() async {
        let empty = ReplayRunner(directory: URL(filePath: "/nonexistent"))
        await #expect(throws: HostError.noFixture("snapshot.json or snapshot.synthetic.json")) {
            try await empty.run(.herdrSnapshot)
        }
    }
}
