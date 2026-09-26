import Foundation
import Testing

@testable import HostKit

/// Runs real local processes (`/bin/sh`, `/bin/sleep`), never ssh, to check output collection, exit statuses and timeouts.
struct ChildProcessTests {
    private func shell(_ script: String) -> ChildProcess {
        ChildProcess(executable: "/bin/sh", arguments: ["-c", script])
    }

    @Test func collectsStdoutStderrAndStatus() async throws {
        let output = try await shell("cat; echo oops >&2; exit 3").run(input: Data("hello".utf8), timeout: .seconds(10))
        #expect(output.status == 3)
        #expect(String(decoding: output.stdout, as: UTF8.self) == "hello")
        #expect(String(decoding: output.stderr, as: UTF8.self).hasPrefix("oops"))
    }

    @Test func stopsACommandThatOutlivesItsTimeout() async {
        await #expect(throws: HostError.timedOut(seconds: 1)) {
            // Directly, not through sh: a shell may ignore the SIGTERM that stops the command.
            try await ChildProcess(executable: "/bin/sleep", arguments: ["30"]).run(input: nil, timeout: .seconds(1))
        }
    }

    @Test func streamsLinesAndReportsTheExitStatus() async {
        var lines: [String] = []
        await #expect(throws: HostError.self) {
            for try await line in shell("printf 'a\\nb\\nc'; exit 2").lines(input: nil) {
                lines.append(line)
            }
        }
        #expect(lines.prefix(2) == ["a", "b"])
    }
}
