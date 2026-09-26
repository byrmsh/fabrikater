import FabrikaterCore
import Foundation
import HerdrKit
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
    private let idle = "─────────────\n❯ \n─────────────\n  ? for shortcuts"
    private let permission = " Do you want to proceed?\n ❯ 1. Yes\n   2. No\n\n Esc to cancel · Tab to amend"

    @Test func sendsThePromptWhenTheInputBoxShows() async throws {
        let control = FakeControl()
        let reader = FakeReader(idle)
        try await SendGuard(control, reader: reader).perform(HerdrRequest.prompt("hello", to: pane))
        #expect(control.performed == HerdrRequest.prompt("hello", to: pane).map { [$0] })
        #expect(reader.reads == 2)
    }

    @Test func sendsNothingWhileADialogShows() async throws {
        let control = FakeControl()
        await #expect(throws: SendGuard.Refusal.dialog(question: "Do you want to proceed?", typed: false)) {
            try await SendGuard(control, reader: FakeReader(permission)).perform(HerdrRequest.prompt("1", to: pane))
        }
        #expect(control.performed.isEmpty)
    }

    @Test func holdsEnterBackWhenADialogAppearsWhileTyping() async throws {
        let control = FakeControl()
        await #expect(throws: SendGuard.Refusal.dialog(question: "Do you want to proceed?", typed: true)) {
            try await SendGuard(control, reader: FakeReader(idle, permission))
                .perform(HerdrRequest.prompt("hello", to: pane))
        }
        #expect(control.performed == [[.sendText(pane, "hello")]])
    }

    @Test func refusesWhenTheScreenCannotBeRead() async throws {
        let control = FakeControl()
        let reader = FakeReader(idle)
        reader.error = HerdrError("timed out")
        await #expect(throws: SendGuard.Refusal.unreadable(String(describing: HerdrError("timed out")))) {
            try await SendGuard(control, reader: reader).perform(HerdrRequest.prompt("hello", to: pane))
        }
        #expect(control.performed.isEmpty)
    }

    @Test func focusNeedsNoScreenRead() async throws {
        let control = FakeControl()
        let reader = FakeReader(permission)
        try await SendGuard(control, reader: reader).perform([.focus(pane)])
        #expect(control.performed == [[.focus(pane)]])
        #expect(reader.reads == 0)
    }
}
