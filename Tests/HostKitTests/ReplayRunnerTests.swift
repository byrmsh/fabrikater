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

    @Test func servesAPaneScreenByPaneThenTheSyntheticOne() async throws {
        let first = try await runner.run(.herdrPaneScreen(try #require(PaneID("w1:p1"))))
        #expect(first == (try Fixture.data(named: "screen-w1-p1.synthetic.txt")))
        let other = try await runner.run(.herdrPaneScreen(try #require(PaneID("w2:p1"))))
        #expect(other == (try Fixture.data(named: "screen.synthetic.txt")))
    }

    @Test func typedTextShowsOnThePromptRowUntilEnter() async throws {
        let pane = try #require(PaneID("w2:p1"))
        let text =
            #"{"id":"a","method":"pane.send_text","params":{"pane_id":"w2:p1","text":"\u001b[200~fix\nit\u001b[201~"}}"#
        let enter = #"{"id":"b","method":"pane.send_keys","params":{"keys":["Enter"],"pane_id":"w2:p1"}}"#
        _ = try await runner.run(.herdrRequests, input: Data("?w2:p1 60 1 1\nhint\n❯\n\(text)\n".utf8))
        let screen = String(decoding: try await runner.run(.herdrPaneScreen(pane)), as: UTF8.self)
        #expect(screen.contains("❯ fix it\r\n"))
        #expect(try await runner.run(.herdrPaneScreen(try #require(PaneID("w3:p1")))) != Data(screen.utf8))
        _ = try await runner.run(.herdrRequests, input: Data("\(enter)\n".utf8))
        #expect(try await runner.run(.herdrPaneScreen(pane)) == (try Fixture.data(named: "screen.synthetic.txt")))
    }

    @Test func streamsTheEventFixtureLineByLine() async throws {
        var lines: [String] = []
        for try await line in runner.lines(.herdrEvents, input: nil) {
            lines.append(line)
            if lines.count == 3 { break }
        }
        #expect(lines.first == #"{"id":"sub1","result":{"type":"subscription_started"}}"#)
    }

    @Test func followsTheLogsTailThenWhatIsAppended() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(component: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appending(component: "claude.synthetic.jsonl")
        try Data("one\ntwo\nthree\n".utf8).write(to: file)
        let runner = ReplayRunner(directory: directory, pollInterval: .milliseconds(10))
        let session = try #require(SessionID("00000000-0000-4000-8000-000000000001"))

        var lines: [String] = []
        for try await line in runner.lines(.claudeLogFollow(session: session, bytes: 8), input: nil) {
            lines.append(line)
            if lines == ["o", "three"] {
                let handle = try FileHandle(forWritingTo: file)
                try handle.seekToEnd()
                try handle.write(contentsOf: Data("fo".utf8))
                try handle.write(contentsOf: Data("ur\n".utf8))
                try handle.close()
            }
            if lines.count == 3 { break }
        }
        #expect(lines == ["o", "three", "four"])
    }

    @Test func failsWithoutAFixture() async {
        let empty = ReplayRunner(directory: URL(filePath: "/nonexistent"))
        await #expect(throws: HostError.noFixture("snapshot.json or snapshot.synthetic.json")) {
            try await empty.run(.herdrSnapshot)
        }
    }
}
