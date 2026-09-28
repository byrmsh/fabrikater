import FabrikaterCore
import Foundation
import HerdrKit
import HostKit
import PromptKit
import Testing

@testable import AppModel

struct SendGuardTests {
    /// Serves one screen per read, in order, repeating the last.
    private final class FakeReader: PaneReader, @unchecked Sendable {
        var screens: [String]
        var error: (any Error)?
        private(set) var reads = 0

        init(_ screens: String...) {
            self.screens = screens
        }

        func screen(of pane: PaneID) async throws -> String {
            if let error { throw error }
            defer { reads += 1 }
            return screens[min(reads, screens.count - 1)]
        }
    }

    private let pane = PaneID("w2:p1")!
    private let permission = " Do you want to proceed?\n ❯ 1. Yes\n   2. No\n\n Esc to cancel · Tab to amend"
    private let shell = "$ ls\nREADME.md\n$ "

    private func box(_ draft: String) -> String {
        "earlier output\n─────────────\n❯\u{A0}\(draft)\n─────────────\n  ? for shortcuts"
    }

    private func guarded(_ control: FakeControl, _ reader: FakeReader) -> SendGuard {
        SendGuard(control, reader: reader, sleep: { _ in })
    }

    private func check(_ screen: String?) -> ScreenCheck {
        SendGuard.check(screen.flatMap { InputBox(on: Screen(ansi: $0)) })
    }

    @Test func typesIntoTheEmptyBoxAndSendsEnterOnceTheBoxShowsTheText() async throws {
        let control = FakeControl()
        let reader = FakeReader(box(""), box(""), box("hello"))
        try await guarded(control, reader).perform(HerdrRequest.prompt("hello", to: pane))
        #expect(
            control.performed == [
                [.checked(check(box("")), .sendText(pane, "hello"))],
                [.checked(check(box("hello")), .sendKeys(pane, [.enter]))],
            ])
        #expect(reader.reads == 3)
    }

    @Test func theHostChecksTheBoxAndTheDialogFooters() {
        let check = check(box("hello"))
        #expect(check.rows == ["─────────────", "❯hello", "─────────────"])
        #expect(check.refusing.contains("entertoselect"))
    }

    @Test func aMultiLinePromptIsVerifiedWithoutItsPasteMarkers() async throws {
        let control = FakeControl()
        let requests = HerdrRequest.prompt("one\ntwo", to: pane)
        try await guarded(control, FakeReader(box(""), box("one two"))).perform(requests)
        #expect(control.performed.count == 2)
    }

    @Test func sendsNothingWhileADialogShows() async throws {
        let control = FakeControl()
        await #expect(throws: SendGuard.Refusal.dialog(question: "Do you want to proceed?", typed: false)) {
            try await guarded(control, FakeReader(permission)).perform(HerdrRequest.prompt("1", to: pane))
        }
        #expect(control.performed.isEmpty)
    }

    @Test func sendsNothingIntoABoxThatAlreadyHoldsText() async throws {
        let control = FakeControl()
        await #expect(throws: SendGuard.Refusal.occupied("half a thought")) {
            try await guarded(control, FakeReader(box("half a thought"))).perform(HerdrRequest.prompt("hi", to: pane))
        }
        #expect(control.performed.isEmpty)
    }

    @Test func holdsEnterBackWhenADialogAppearsWhileTyping() async throws {
        let control = FakeControl()
        await #expect(throws: SendGuard.Refusal.dialog(question: "Do you want to proceed?", typed: true)) {
            try await guarded(control, FakeReader(box(""), permission)).perform(HerdrRequest.prompt("hello", to: pane))
        }
        #expect(control.performed == [[.checked(check(box("")), .sendText(pane, "hello"))]])
    }

    @Test func holdsEnterBackWhenTheTextNeverShows() async throws {
        let control = FakeControl()
        let reader = FakeReader(box(""), box(""), box("hello, wrld"))
        await #expect(throws: SendGuard.Refusal.unverified) {
            try await guarded(control, reader).perform(HerdrRequest.prompt("hello, world", to: pane))
        }
        #expect(control.performed.count == 1)
        #expect(reader.reads == 1 + ScreenWait.reads)
    }

    @Test func aScreenThatChangedOnTheHostIsARefusal() async throws {
        let control = FakeControl()
        control.error = HerdrError.screenChanged
        await #expect(throws: SendGuard.Refusal.changed(typed: false)) {
            try await guarded(control, FakeReader(box(""))).perform(HerdrRequest.prompt("hello", to: pane))
        }
    }

    /// Without an input box it knows, the guard checks each request's screen for a dialog, here and on the host.
    @Test func withoutAnInputBoxEachRequestIsCheckedForADialog() async throws {
        let control = FakeControl()
        let reader = FakeReader(shell)
        try await guarded(control, reader).perform(HerdrRequest.prompt("hello", to: pane))
        #expect(control.performed == HerdrRequest.prompt("hello", to: pane).map { [.checked(check(nil), $0)] })
        #expect(reader.reads == 2)
    }

    @Test func refusesWhenTheScreenCannotBeRead() async throws {
        let control = FakeControl()
        let reader = FakeReader(box(""))
        reader.error = HerdrError("timed out")
        await #expect(throws: SendGuard.Refusal.unreadable(String(describing: HerdrError("timed out")))) {
            try await guarded(control, reader).perform(HerdrRequest.prompt("hello", to: pane))
        }
        #expect(control.performed.isEmpty)
    }

    @Test func escapeAndControlCGoThroughADialogToCancelIt() async throws {
        let control = FakeControl()
        let reader = FakeReader(permission)
        try await guarded(control, reader).perform([.sendKeys(pane, [.escape])])
        try await guarded(control, reader).perform([.sendKeys(pane, [.ctrlC])])
        #expect(control.performed == [[.sendKeys(pane, [.escape])], [.sendKeys(pane, [.ctrlC])]])
        #expect(reader.reads == 0)
        await #expect(throws: SendGuard.Refusal.dialog(question: "Do you want to proceed?", typed: false)) {
            try await guarded(control, reader).perform([.sendKeys(pane, [.tab])])
        }
    }

    @Test func focusNeedsNoScreenRead() async throws {
        let control = FakeControl()
        let reader = FakeReader(permission)
        try await guarded(control, reader).perform([.focus(pane)])
        #expect(control.performed == [[.focus(pane)]])
        #expect(reader.reads == 0)
    }
}

/// The guard over the real client and the real host script, run locally with a fake `herdr` that shows Collie's
/// captures and a fake `socat` that records what reaches Herdr's socket and makes the typed text appear in the box.
@Suite struct SendGuardOnTheHostScriptTests {
    private let directory: URL
    private let pane = PaneID("w1:p1")!

    init() throws {
        directory = FileManager.default.temporaryDirectory.appending(component: "fabrikater-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try script("herdr", #"if [ -s "$D/sent" ]; then cat "$D/after"; else cat "$D/before"; fi"#)
        try script(
            "socat", #"IFS= read -r l; printf '%s\n' "$l" >> "$D/sent"; echo '{"id":"x","result":{"type":"ok"}}'"#)
    }

    private func script(_ name: String, _ body: String) throws {
        let file = directory.appending(component: name)
        try Data("#!/bin/sh\n\(body)\n".utf8).write(to: file)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
    }

    /// Runs each command's remote script under `/bin/sh` here instead of over ssh.
    private struct LocalRunner: HostCommandRunner {
        let directory: URL

        func run(_ command: HostCommand, input: Data?) async throws(HostError) -> Data {
            let process = Process()
            process.executableURL = URL(filePath: "/bin/sh")
            process.arguments = ["-c", command.remoteScript]
            process.environment = [
                "PATH": "\(directory.path):/usr/bin:/bin", "D": directory.path, "HOME": directory.path,
            ]
            let stdin = Pipe()
            let stdout = Pipe()
            process.standardInput = stdin
            process.standardOutput = stdout
            do { try process.run() } catch { throw .launchFailed(String(describing: error)) }
            stdin.fileHandleForWriting.write(input ?? Data())
            try? stdin.fileHandleForWriting.close()
            let data = stdout.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return data
        }

        func lines(_ command: HostCommand, input: Data?) -> AsyncThrowingStream<String, any Error> {
            AsyncThrowingStream { $0.finish() }
        }
    }

    /// Sends `text` with the pane showing capture `name` before typing, and the same screen with `typed` in its
    /// input box afterwards. Returns the requests that reached Herdr.
    private func send(_ text: String, on name: String, typed: String) async throws -> [String] {
        let before = try String(decoding: Fixture.data(named: "panes/\(name).txt"), as: UTF8.self)
        let prompt = try #require(before.ranges(of: /❯[^\r\n]*/).last)
        let after = before.replacingCharacters(in: prompt, with: "❯\u{A0}\(typed)")
        try Data(before.utf8).write(to: directory.appending(component: "before"))
        try Data(after.utf8).write(to: directory.appending(component: "after"))
        let client = HerdrClient(runner: LocalRunner(directory: directory))
        try await SendGuard(client, reader: client, sleep: { _ in }).perform(HerdrRequest.prompt(text, to: pane))
        let sent = (try? String(contentsOf: directory.appending(component: "sent"), encoding: .utf8)) ?? ""
        return sent.split(separator: "\n").map(String.init)
    }

    @Test(arguments: ["claude--fresh-idle", "claude--done", "claude--working", "claude-lab--statusline-3row--w82"])
    func aPromptReachesTheBoxThenEnterFollows(_ name: String) async throws {
        let sent = try await send("hello there", on: name, typed: "hello there")
        #expect(sent.count == 2)
        #expect(sent.first?.contains(#""method":"pane.send_text""#) == true)
        #expect(sent.last?.contains(#""keys":["Enter"]"#) == true)
    }

    @Test func textThatNeverShowsGetsNoEnter() async throws {
        await #expect(throws: SendGuard.Refusal.unverified) {
            _ = try await send("hello there", on: "claude--fresh-idle", typed: "")
        }
        let sent = try String(contentsOf: directory.appending(component: "sent"), encoding: .utf8)
        #expect(sent.split(separator: "\n").count == 1)
    }
}
