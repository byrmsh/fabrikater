import FabrikaterCore
import Foundation
import HerdrKit
import Testing
import TranscriptKit

@testable import AppModel

@MainActor
struct PaneAlertTests {
    private struct NoTranscripts: TranscriptService {
        func claudeTranscript(session: SessionID, bytes: Int) async throws -> Transcript { Transcript() }
    }

    private let refactor = PaneID("w1:p1")!
    private let codex = PaneID("w1:pB")!
    private let scratch = PaneID("w2:p1")!

    private final class Frontmost {
        var isActive = true
    }

    private func makeStore(
        _ notifier: RecordingNotifier, frontmost: Frontmost = Frontmost(), notes: PaneNotes = PaneNotes()
    ) throws -> (AppStore, Herd) {
        let herd = try Herd(snapshotReply: Fixture.data(named: "snapshot.synthetic.json"))
        let store = AppStore(
            herdUpdates: AsyncStream { $0.finish() }, transcripts: NoTranscripts(), control: FakeControl(),
            notes: InMemoryPaneNotesStore(notes), notifier: notifier, isAppActive: { frontmost.isActive })
        store.apply(.herd(herd))
        return (store, herd)
    }

    private func setting(_ changes: [PaneID: AgentStatus], in herd: Herd) -> Herd {
        var herd = herd
        herd.panes = herd.panes.map { pane in
            var pane = pane
            pane.agentStatus = changes[pane.id] ?? pane.agentStatus
            return pane
        }
        return herd
    }

    @Test func theFirstHerdNotifiesNothing() throws {
        let notifier = RecordingNotifier()
        _ = try makeStore(notifier)
        #expect(notifier.alerts.isEmpty)
    }

    @Test func becomingBlockedAndFinishingATurnNotify() throws {
        let notifier = RecordingNotifier()
        let (store, herd) = try makeStore(notifier)
        store.apply(.herd(setting([refactor: .blocked], in: herd)))
        store.apply(.herd(setting([refactor: .working], in: herd)))
        store.apply(.herd(setting([refactor: .done], in: herd)))
        #expect(
            notifier.alerts == [
                PaneAlert(
                    paneID: refactor, title: "Synthetic refactor", subtitle: "Synthetic A › api", body: "Needs input"),
                PaneAlert(
                    paneID: refactor, title: "Synthetic refactor", subtitle: "Synthetic A › api",
                    body: "Finished its turn"),
            ])
    }

    @Test(arguments: [
        (AgentStatus.working, AgentStatus.idle), (.idle, .done), (.done, .working), (.blocked, .blocked),
        (.unknown, .done),
    ])
    func otherTransitionsStayQuiet(_ from: AgentStatus, _ to: AgentStatus) throws {
        let notifier = RecordingNotifier()
        let (store, herd) = try makeStore(notifier)
        store.apply(.herd(setting([scratch: from], in: herd)))
        let before = notifier.alerts.count
        store.apply(.herd(setting([scratch: to], in: herd)))
        #expect(notifier.alerts.count == before)
    }

    @Test func theSelectedPaneIsQuietWhileTheAppIsFrontmost() throws {
        let notifier = RecordingNotifier()
        let frontmost = Frontmost()
        let (store, herd) = try makeStore(notifier, frontmost: frontmost)
        store.perform(.selectPane(refactor))
        store.apply(.herd(setting([refactor: .done], in: herd)))
        #expect(notifier.alerts.isEmpty)
        store.apply(.herd(herd))
        frontmost.isActive = false
        store.apply(.herd(setting([refactor: .done], in: herd)))
        #expect(notifier.alerts.map(\.paneID) == [refactor])
    }

    @Test func anotherPaneNotifiesWhileTheAppIsFrontmost() throws {
        let notifier = RecordingNotifier()
        let (store, herd) = try makeStore(notifier)
        store.perform(.selectPane(scratch))
        store.apply(.herd(setting([refactor: .done], in: herd)))
        #expect(notifier.alerts.map(\.paneID) == [refactor])
    }

    @Test func aMutedWorkspaceIsQuietAndTheMenuSaysSo() throws {
        let notifier = RecordingNotifier()
        let (store, herd) = try makeStore(notifier)
        #expect(store.title(of: .toggleNotifications("w1")) == "Turn Off Notifications")
        store.perform(.toggleNotifications("w1"))
        #expect(store.title(of: .toggleNotifications("w1")) == "Turn On Notifications")
        store.apply(.herd(setting([refactor: .done, scratch: .blocked], in: setting([scratch: .idle], in: herd))))
        #expect(notifier.alerts.map(\.paneID) == [scratch])
        store.perform(.toggleNotifications("w1"))
        #expect(store.title(of: .toggleNotifications("w1")) == "Turn Off Notifications")
    }

    @Test func aRenamedPaneIsNotifiedByItsName() throws {
        let notifier = RecordingNotifier()
        let (store, herd) = try makeStore(notifier, notes: PaneNotes(names: [refactor: "API work"]))
        store.apply(.herd(setting([refactor: .blocked], in: herd)))
        #expect(notifier.alerts.map(\.title) == ["API work"])
    }

    @Test func mutedWorkspacesRoundTripAndOldNotesDecode() throws {
        let old = try JSONDecoder().decode(PaneNotes.self, from: Data(#"{"names":{},"pins":[]}"#.utf8))
        #expect(old.mutedWorkspaces.isEmpty)
        let notes = PaneNotes(mutedWorkspaces: ["w1", "w2"])
        #expect(try JSONDecoder().decode(PaneNotes.self, from: JSONEncoder().encode(notes)) == notes)
    }

    @Test func aPaneWindowCannotMuteTheSelectedWorkspace() throws {
        let (store, _) = try makeStore(RecordingNotifier())
        let window = store.paneWindow(refactor)
        #expect(MenuTarget(app: store, window: window).route(.toggleNotifications(nil)) == .unavailable)
        #expect(MenuTarget(app: store).route(.toggleNotifications("w1")) == .app(.toggleNotifications("w1")))
    }
}
