import FabrikaterCore
import Foundation
import HostKit
import Testing

@testable import HerdrKit

struct HerdrClientTests {
    /// Streams fixed lines and records the stdin it was given.
    private struct LinesRunner: HostCommandRunner {
        let lines: [String]

        func run(_ command: HostCommand, input: Data?) async throws(HostError) -> Data { Data() }

        func lines(_ command: HostCommand, input: Data?) -> AsyncThrowingStream<String, any Error> {
            AsyncThrowingStream { continuation in
                for line in lines { continuation.yield(line) }
                continuation.finish()
            }
        }
    }

    @Test func subscribeRequestIsOneValidJSONLine() throws {
        let request = HerdrClient.subscribeRequest
        #expect(request.last == 0x0A)
        #expect(request.filter { $0 == 0x0A }.count == 1)
        let object = try #require(try JSONSerialization.jsonObject(with: request) as? [String: Any])
        #expect(object["method"] as? String == "events.subscribe")
        let params = try #require(object["params"] as? [String: Any])
        let subscriptions = try #require(params["subscriptions"] as? [[String: String]])
        #expect(subscriptions.map { $0["type"] } == HerdrClient.subscriptions)
    }

    @Test func pokesOncePerEventIncludingTheAcknowledgement() async throws {
        let client = HerdrClient(
            runner: LinesRunner(lines: [
                #"{"id":"sub1","result":{"type":"subscription_started"}}"#, #"{"type":"pane_updated"}"#, "",
                #"{"type":"pane_updated","title":"\"error\""}"#,
            ]))
        var pokes = 0
        for try await _ in client.events() { pokes += 1 }
        #expect(pokes == 3)
    }

    @Test func failsWhenHerdrRefusesTheSubscription() async {
        let client = HerdrClient(runner: LinesRunner(lines: [#"{"id":"sub1","error":{"message":"bad type"}}"#]))
        await #expect(throws: HerdrError.self) {
            for try await _ in client.events() {}
        }
    }

    @Test func readsTheSnapshotThroughTheReplayRunner() async throws {
        let client = HerdrClient(runner: ReplayRunner(directory: Fixture.directory))
        let herd = try await client.snapshot()
        #expect(!herd.panes.isEmpty)
    }
}
