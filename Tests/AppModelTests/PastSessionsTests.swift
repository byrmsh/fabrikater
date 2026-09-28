import FabrikaterCore
import Foundation
import HerdrKit
import Testing
import TranscriptKit

@testable import AppModel

@MainActor
struct PastSessionsTests {
    /// Answers each session with one entry naming it.
    private struct NamingTranscripts: TranscriptService {
        func transcript(of log: SessionLog, bytes: Int) async throws -> Transcript {
            Transcript(entries: [TranscriptEntry(id: "e1", role: .user, parts: [.text(log.session.rawValue)])])
        }
    }

    private struct FakeHistory: SessionHistory {
        var result: Result<[PastSession], TranscriptError>

        func pastSessions(besides log: SessionLog) async throws -> [PastSession] {
            try result.get()
        }
    }

    nonisolated private static let now = Date(timeIntervalSince1970: 1_790_500_000)
    private let refactor = PaneID("w1:p1")!

    private static func session(_ suffix: String, title: String, age: TimeInterval, bytes: Int = 2048) -> PastSession {
        PastSession(
            log: SessionLog(format: .claude, session: SessionID("00000000-0000-4000-8000-0000000000\(suffix)")!),
            modified: now.addingTimeInterval(-age), bytes: bytes, title: title, isCurrent: suffix == "01")
    }

    private let clipboard = InMemoryClipboard()

    private func makeStore(
        _ result: Result<[PastSession], TranscriptError>, snapshot: String = "snapshot.synthetic.json"
    ) throws -> AppStore {
        let store = AppStore(
            herdUpdates: AsyncStream { $0.finish() }, transcripts: NamingTranscripts(),
            history: FakeHistory(result: result), control: FakeControl(), clipboard: clipboard, now: { Self.now })
        store.apply(.herd(try Herd(snapshotReply: Fixture.data(named: snapshot))))
        return store
    }

    @Test func listsTheSelectedPanesSessions() async throws {
        let store = try makeStore(
            .success([
                Self.session("01", title: "", age: 20),
                Self.session("a1", title: "Add a retry", age: 7200, bytes: 1_245_184),
            ]))
        store.perform(.selectPane(refactor))
        #expect(store.isEnabled(.showPastSessions(nil)))
        store.perform(.showPastSessions(nil))
        #expect(store.pastSessions.sheet?.title == "Sessions in project-1")
        #expect(store.pastSessions.sheet?.isLoading == true)
        #expect(store.pastSessions.sheet?.emptyMessage == "Loading sessions…")
        await store.pastSessions.loadTask?.value

        let sheet = try #require(store.pastSessions.sheet)
        #expect(!sheet.isLoading)
        #expect(sheet.emptyMessage == nil)
        #expect(sheet.rows.map(\.title) == ["New session", "Add a retry"])
        #expect(sheet.rows.map(\.age) == ["Just now", "2h ago"])
        #expect(sheet.rows.map(\.size) == ["2 KB", "1.2 MB"])
        #expect(sheet.rows.map(\.badge) == ["Current", nil])
        #expect(sheet.rows[1].spoken == "Add a retry, Active 2 hours ago, 1.2 MB")
        #expect(sheet.rows[1].window.title == "Add a retry")

        #expect(store.isEnabled(.openPastSession(sheet.rows[1].window)))
        #expect(!store.isEnabled(.openPastSession(SessionWindowID(log: sheet.rows[1].window.log, title: "Other"))))
        store.perform(.openPastSession(sheet.rows[1].window))
        #expect(store.pastSessions.sheet == nil)
        store.perform(.showPastSessions(nil))
        #expect(store.isEnabled(.closePastSessions))
        store.perform(.closePastSessions)
        #expect(store.pastSessions.sheet == nil)
        #expect(!store.isEnabled(.closePastSessions))
    }

    @Test func saysWhenThereIsNothingElse() async throws {
        let store = try makeStore(.success([Self.session("01", title: "Only", age: 20)]))
        store.perform(.showPastSessions(refactor))
        await store.pastSessions.loadTask?.value
        #expect(store.pastSessions.sheet?.emptyMessage == "No other sessions in this folder.")
    }

    @Test func saysWhyTheListingFailed() async throws {
        let store = try makeStore(.failure(.noLog))
        store.perform(.showPastSessions(refactor))
        await store.pastSessions.loadTask?.value
        #expect(store.pastSessions.sheet?.rows.isEmpty == true)
        #expect(
            store.pastSessions.sheet?.emptyMessage == "Could not list sessions: No session log was found for this pane")
    }

    @Test func panesWhoseLogIsReadListSessions() throws {
        let store = try makeStore(.success([]), snapshot: "snapshot-agents.synthetic.json")
        #expect(!store.isEnabled(.showPastSessions(nil)))
        #expect(store.isEnabled(.showPastSessions(refactor)))
        #expect(store.isEnabled(.showPastSessions(PaneID("w1:pB")!)))
        #expect(store.isEnabled(.showPastSessions(PaneID("w2:p2")!)))
        #expect(store.isEnabled(.showPastSessions(PaneID("w2:p3")!)))
        #expect(!store.isEnabled(.showPastSessions(PaneID("w1:pA")!)))
        store.perform(.showPastSessions(PaneID("w1:pA")!))
        #expect(store.pastSessions.sheet == nil)
        store.perform(.showPastSessions(PaneID("w1:pB")!))
        #expect(store.pastSessions.sheet?.title == "Sessions in project-2")
    }

    @Test func aSessionWindowReadsItsOwnLog() async throws {
        let store = try makeStore(.success([]))
        let id = SessionWindowID(log: Self.session("a1", title: "Add a retry", age: 0).log, title: "Add a retry")
        let window = store.sessionWindow(id)
        await window.conversation.loadTask?.value
        #expect(window.title == "Add a retry")
        #expect(window.conversation.paneID == nil)
        guard case .text(let text, _) = window.conversation.transcript.entries.first?.parts.first else {
            Issue.record("no conversation")
            return
        }
        #expect(text == "00000000-0000-4000-8000-0000000000a1")
        #expect(window.isEnabled(.copyConversation))
        #expect(window.isEnabled(.reloadConversation))
        #expect(!window.isEnabled(.send))
    }

    @Test func aSessionWindowInFrontTakesTheConversationCommands() async throws {
        let store = try makeStore(.success([]))
        store.perform(.selectPane(refactor))
        let id = SessionWindowID(log: Self.session("a1", title: "Add a retry", age: 0).log, title: "Add a retry")
        let window = store.sessionWindow(id)
        await window.conversation.loadTask?.value
        let target = MenuTarget(app: store, session: window)

        #expect(target.route(.reloadConversation) == .session(.reloadConversation))
        #expect(target.route(.loadEarlier) == .session(.loadEarlier))
        target.perform(.copyConversation)
        #expect(clipboard.text?.contains("00000000-0000-4000-8000-0000000000a1") == true)
    }

    @Test func aSessionWindowHasNoPaneToActOn() throws {
        let store = try makeStore(.success([]))
        store.perform(.selectPane(refactor))
        let id = SessionWindowID(log: Self.session("a1", title: "Add a retry", age: 0).log, title: "Add a retry")
        let target = MenuTarget(app: store, session: store.sessionWindow(id))

        for command in [
            AppCommand.send, .sendKey(.escape), .toggleTerminal, .toggleChanges, .togglePin(nil), .openInVSCode(nil),
            .openInNewWindow(nil), .showPastSessions(nil), .renamePane(nil),
        ] {
            #expect(target.route(command) == .unavailable)
            #expect(!target.isEnabled(command))
        }
        #expect(target.promptOptions.isEmpty)
        #expect(target.route(.selectNextPane) == .app(.selectNextPane))
        #expect(target.route(.biggerText) == .app(.biggerText))
    }

    @Test func aPaneWindowLeavesTheSheetToTheMainWindow() throws {
        let store = try makeStore(.success([]))
        let target = MenuTarget(app: store, window: store.paneWindow(refactor))
        #expect(target.route(.showPastSessions(nil)) == .unavailable)
    }

    @Test(arguments: [
        (0, "0 bytes"), (1, "1 byte"), (731, "731 bytes"), (1024, "1 KB"), (1536, "1.5 KB"), (48_213, "47 KB"),
        (1_245_184, "1.2 MB"), (10_485_760, "10 MB"), (3 * 1_073_741_824, "3 GB"),
    ])
    func sizesReadInTheLargestUnit(bytes: Int, text: String) {
        #expect(PastSessionRow.size(bytes) == text)
    }
}
