import Foundation
import Testing

@testable import HostKit

/// Runs the requests script with a fake `herdr` that prints a screen and a fake `socat` that records what reaches
/// Herdr's socket, as the host would run it.
@Suite struct RequestsScriptTests {
    private let directory: URL
    private let screen: URL
    private let sent: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory.appending(component: "fabrikater-\(UUID().uuidString)")
        screen = directory.appending(component: "screen.txt")
        sent = directory.appending(component: "sent.jsonl")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try script("herdr", #"[ "$3" = w1:p1 ] && [ -f "$SCREEN" ] && cat "$SCREEN""#)
        try script("socat", #"IFS= read -r l; printf '%s\n' "$l" >> "$SENT"; echo '{"id":"x","result":{"type":"ok"}}'"#)
    }

    private func script(_ name: String, _ body: String) throws {
        let file = directory.appending(component: name)
        try Data("#!/bin/sh\n\(body)\n".utf8).write(to: file)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
    }

    /// What the script printed, and the requests that reached the socket.
    private func run(_ lines: [String]) throws -> (output: [String], sent: [String]) {
        let process = Process()
        process.executableURL = URL(filePath: "/bin/sh")
        process.arguments = ["-c", HostCommand.herdrRequests.remoteScript]
        process.environment = [
            "PATH": "\(directory.path):/usr/bin:/bin", "SCREEN": screen.path, "SENT": sent.path, "HOME": directory.path,
        ]
        let input = Pipe()
        let output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        try process.run()
        input.fileHandleForWriting.write(Data(lines.map { $0 + "\n" }.joined().utf8))
        try input.fileHandleForWriting.close()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
        let sentLines = (try? String(contentsOf: sent, encoding: .utf8)) ?? ""
        return (
            String(decoding: data, as: UTF8.self).split(separator: "\n").map(String.init),
            sentLines.split(separator: "\n").map(String.init)
        )
    }

    private func show(_ text: String) throws {
        try Data(text.utf8).write(to: screen)
    }

    private let request =
        #"{"id":"fabrikater1","method":"pane.send_keys","params":{"keys":["Enter"],"pane_id":"w1:p1"}}"#
    private let changed = #"{"error":{"code":"screen_changed","message":"screen check failed"}}"#
    private let box =
        "\u{1B}[2m──────────\u{1B}[0m\r\n❯\u{A0}fix the parser  \r\n──────────\r\n  \u{1B}[1mstatus\u{1B}[0m\r\n\r\n"

    @Test func unguardedRequestsAreSentInOrder() throws {
        let result = try run([request, request])
        #expect(result.sent == [request, request])
        #expect(result.output.count == 2)
    }

    @Test func sendsWhenTheRowsShowWhateverTheStylingAndSpacing() throws {
        try show(box)
        let result = try run(["?w1:p1 10 1 3", "entertoselect", "──────────", "❯fixtheparser", "──────────", request])
        #expect(result.sent == [request])
        #expect(result.output == [#"{"id":"x","result":{"type":"ok"}}"#])
    }

    @Test func refusesWhenTheRowsAreGone() throws {
        try show(box.replacing("fix the parser", with: "1. Yes"))
        let result = try run(["?w1:p1 10 0 3", "──────────", "❯fixtheparser", "──────────", request, request])
        #expect(result.sent.isEmpty)
        #expect(result.output == [changed])
    }

    @Test func refusesWhenTheRowsAreAboveTheWindow() throws {
        try show(box + "one\ntwo\nthree\n")
        #expect(try run(["?w1:p1 5 0 1", "❯fixtheparser", request]).sent.isEmpty)
        #expect(try run(["?w1:p1 6 0 1", "❯fixtheparser", request]).sent == [request])
    }

    @Test func refusesWhenTheFooterNamesADialog() throws {
        try show("Do you want to proceed?\n❯ 1. Yes\n  2. No\n\nEsc to cancel · Tab to amend\n")
        let result = try run(["?w1:p1 10 2 0", "entertoselect", "esctocancel", request])
        #expect(result.sent.isEmpty)
        #expect(result.output == [changed])
    }

    @Test func refusesWhenTheScreenCannotBeRead() throws {
        #expect(try run(["?w1:p1 10 0 0", request]).output == [changed])
    }

    @Test func onlyTheRequestAfterTheCheckWaitsForIt() throws {
        try show(box)
        let result = try run([request, "?w1:p1 10 0 1", "❯somethingelse", request])
        #expect(result.sent == [request])
        #expect(result.output.last == changed)
    }
}
