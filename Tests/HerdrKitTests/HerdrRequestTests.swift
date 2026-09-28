import FabrikaterCore
import Foundation
import HostKit
import Testing

@testable import HerdrKit

struct HerdrRequestTests {
    private let pane = PaneID("w2:p1")!

    /// Answers every request with fixed output and records the stdin it was given.
    private final class RecordingRunner: HostCommandRunner, @unchecked Sendable {
        let output: String
        private(set) var commands: [HostCommand] = []
        private(set) var input = ""

        init(output: String) {
            self.output = output
        }

        func run(_ command: HostCommand, input: Data?) async throws(HostError) -> Data {
            commands.append(command)
            self.input = String(decoding: input ?? Data(), as: UTF8.self)
            return Data(output.utf8)
        }

        func lines(_ command: HostCommand, input: Data?) -> AsyncThrowingStream<String, any Error> {
            AsyncThrowingStream { $0.finish() }
        }
    }

    @Test func aOneLinePromptIsTheTextThenEnter() {
        #expect(HerdrRequest.prompt("  fix it\n", to: pane) == [.sendText(pane, "fix it"), .sendKeys(pane, [.enter])])
        #expect(HerdrRequest.prompt(" \n ", to: pane).isEmpty)
    }

    @Test func aMultiLinePromptIsPastedSoItsNewlinesDoNotSubmit() {
        #expect(HerdrRequest.prompt("a\nb", to: pane).first == .sendText(pane, "\u{1B}[200~a\nb\u{1B}[201~"))
    }

    @Test func requestsAreSingleJSONLines() throws {
        let line = HerdrRequest.sendText(pane, "say \"hi\"\n$(rm -rf ~)\u{1B}").line(id: "r1")
        #expect(!line.contains("\n"))
        let object = try #require(try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
        #expect(object["method"] as? String == "pane.send_text")
        let params = try #require(object["params"] as? [String: String])
        #expect(params == ["pane_id": "w2:p1", "text": "say \"hi\"\n$(rm -rf ~)\u{1B}"])
        #expect(
            HerdrRequest.focus(pane).line(id: "r2")
                == #"{"id":"r2","method":"pane.focus","params":{"pane_id":"w2:p1"}}"#)
        #expect(
            HerdrRequest.sendKeys(pane, [.escape, .ctrlC]).line(id: "r3")
                == #"{"id":"r3","method":"pane.send_keys","params":{"keys":["Escape","ctrl+c"],"pane_id":"w2:p1"}}"#)
    }

    @Test func theClientSendsTheRequestsOnStdinInOneCommand() async throws {
        let reply = #"{"id":"fabrikater1","result":{"type":"ok"}}"# + "\n"
        let runner = RecordingRunner(output: reply + reply)
        try await HerdrClient(runner: runner).perform(HerdrRequest.prompt("hello", to: pane))
        #expect(runner.commands == [.herdrRequests])
        let lines = runner.input.split(separator: "\n")
        #expect(lines.count == 2)
        #expect(lines[0].contains(#""method":"pane.send_text""#))
        #expect(lines[1].contains(#""method":"pane.send_keys""#))
    }

    @Test func aCheckedRequestFollowsItsScreenCheck() {
        let check = ScreenCheck(rows: ["─── x ─", "❯\u{A0}fix  it", "  "], refusing: ["Enter to select"], window: 2)
        #expect(check.rows == ["───x─", "❯fixit"])
        #expect(
            HerdrRequest.checked(check, .sendKeys(pane, [.enter])).lines(id: "r1") == [
                "?w2:p1 2 1 2", "entertoselect", "───x─", "❯fixit",
                #"{"id":"r1","method":"pane.send_keys","params":{"keys":["Enter"],"pane_id":"w2:p1"}}"#,
            ])
        #expect(HerdrRequest.checked(check, .sendText(pane, "a")).typesIntoPane)
        #expect(HerdrRequest.checked(check, .focus(pane)).pane == pane)
    }

    @Test func aFailedScreenCheckIsItsOwnError() async {
        let runner = RecordingRunner(
            output: #"{"error":{"code":"screen_changed","message":"screen check failed"}}"# + "\n")
        await #expect(throws: HerdrError.screenChanged) {
            try await HerdrClient(runner: runner).perform([
                .checked(ScreenCheck(rows: [], refusing: [], window: 1), .focus(pane))
            ])
        }
    }

    @Test func theClientThrowsWhenHerdrRefusesARequest() async {
        let runner = RecordingRunner(
            output: #"{"id":"fabrikater1","error":{"code":"pane_not_found","message":"no such pane"}}"# + "\n")
        await #expect(throws: HerdrError("no such pane")) {
            try await HerdrClient(runner: runner).perform([.focus(pane)])
        }
    }

    @Test func missingOrUnreadableRepliesAreFailures() async {
        for output in ["", #"{"id":"fabrikater1","result":{"type":"ok"}}"#, "socat: connection refused"] {
            await #expect(throws: HerdrError.self) {
                try await HerdrClient(runner: RecordingRunner(output: output)).perform(
                    HerdrRequest.prompt("hi", to: pane))
            }
        }
    }

    @Test func requestsReplayFromFixtures() async throws {
        try await HerdrClient(runner: ReplayRunner(directory: Fixture.directory)).perform([.focus(pane)])
    }
}
