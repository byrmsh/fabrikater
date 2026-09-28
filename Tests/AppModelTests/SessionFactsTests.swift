import FabrikaterCore
import Foundation
import HerdrKit
import Testing
import TranscriptKit

@testable import AppModel

@MainActor
struct SessionFactsRowsTests {
    private struct FixedTranscripts: TranscriptService {
        let transcript: Transcript

        func claudeTranscript(session: SessionID, bytes: Int) async throws -> Transcript { transcript }
    }

    private var utc: Date.FormatStyle {
        var style = Date.FormatStyle(date: .numeric, time: .shortened, locale: Locale(identifier: "en_US_POSIX"))
        style.timeZone = TimeZone(identifier: "UTC")!
        return style
    }

    @Test func formatsTheStartWithTheStyleGiven() {
        #expect(facts.rows(isClipped: false, dateStyle: utc)[3].value.contains("9:15"))
    }

    // 2026-09-26 09:15 UTC. The rows format it with the style given; how that style spells a date is ICU's business.
    private static let start = Date(timeIntervalSince1970: 1_790_414_100)

    private let facts = SessionFacts(
        model: "claude-opus-4-1-20250805",
        workingDirectory: "/home/user/project",
        gitBranch: "main",
        firstSeen: Self.start,
        contextTokens: 84_208
    )

    @Test func listsEveryFactInOrder() {
        #expect(
            facts.rows(isClipped: false, dateStyle: utc) == [
                FactRow("Model", "claude-opus-4-1-20250805"),
                FactRow("Folder", "/home/user/project"),
                FactRow("Branch", "main"),
                FactRow("Started", Self.start.formatted(utc)),
                FactRow("Context", "84.2k tokens"),
            ])
    }

    @Test func aClippedLogSaysItsFirstTimeIsOnlyTheEarliestRead() {
        #expect(facts.rows(isClipped: true, dateStyle: utc)[3] == FactRow("Earliest read", Self.start.formatted(utc)))
    }

    @Test func leavesOutAbsentFacts() {
        #expect(SessionFacts(gitBranch: "main").rows(isClipped: false) == [FactRow("Branch", "main")])
        #expect(SessionFacts().rows(isClipped: false).isEmpty)
    }

    private func makeStore() async throws -> AppStore {
        let store = AppStore(
            herdUpdates: AsyncStream { $0.finish() },
            transcripts: FixedTranscripts(transcript: Transcript(facts: SessionFacts(gitBranch: "main"))),
            control: FakeControl())
        store.apply(.herd(try Herd(snapshotReply: Fixture.data(named: "snapshot.synthetic.json"))))
        return store
    }

    @Test func thePopoverNeedsASelectedPane() async throws {
        let store = try await makeStore()
        #expect(!store.isEnabled(.toggleSessionFacts))
        store.perform(.toggleSessionFacts)
        #expect(!store.isShowingSessionFacts)

        store.perform(.selectPane(PaneID("w2:p1")!))
        await store.conversation.loadTask?.value
        #expect(store.isEnabled(.toggleSessionFacts))
        store.perform(.toggleSessionFacts)
        #expect(store.isShowingSessionFacts)
        #expect(store.conversation.factRows == [FactRow("Branch", "main")])
        store.perform(.toggleSessionFacts)
        #expect(!store.isShowingSessionFacts)
    }

    @Test func theWindowClosesItAndSoDoesClearingTheSelection() async throws {
        let store = try await makeStore()
        store.perform(.selectPane(PaneID("w2:p1")!))
        store.perform(.setSessionFactsShown(true))
        #expect(store.isShowingSessionFacts)
        store.perform(.setSessionFactsShown(false))
        #expect(!store.isShowingSessionFacts)

        store.perform(.toggleSessionFacts)
        store.perform(.selectPane(nil))
        #expect(!store.isShowingSessionFacts)
    }

    @Test func staysOpenWhileMovingBetweenPanes() async throws {
        let store = try await makeStore()
        store.perform(.selectPane(PaneID("w2:p1")!))
        store.perform(.toggleSessionFacts)
        store.perform(.selectNextPane)
        #expect(store.isShowingSessionFacts)
    }

    @Test func hasTheGetInfoShortcut() {
        #expect(Keymap.chord(for: .toggleSessionFacts) == KeyChord(.character("i")))
    }
}
