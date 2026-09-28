import FabrikaterCore
import Foundation
import HerdrKit
import Testing
import TranscriptKit

@testable import AppModel

@MainActor
struct PreferencesTests {
    private struct NoTranscripts: TranscriptService {
        func transcript(of log: SessionLog, bytes: Int) async throws -> Transcript { Transcript() }
    }

    private let refactor = PaneID("w1:p1")!

    private func store(
        _ storage: InMemoryPreferencesStorage = InMemoryPreferencesStorage(), connectedHost: String = "arch"
    )
        -> PreferencesStore
    {
        PreferencesStore(storage: storage, connectedHost: connectedHost, isValidHost: { !$0.hasPrefix("-") })
    }

    @Test func theDefaultsMatchTheDesign() {
        let preferences = Preferences()
        #expect(preferences.host == nil)
        #expect(preferences.sendKey == .return)
        #expect(preferences.notifiesBlocked && preferences.notifiesFinished && preferences.playsSound)
        #expect(preferences.conversationScale(.actual) == 1)
        #expect(preferences.terminalFontSize(.actual) == 12)
        #expect(SendKey.commandReturn.composerPlaceholder == "Message the agent. ⌘Return sends, Return adds a line.")
    }

    @Test func textSizesClampAndCombineWithTheWindowsSteps() {
        var preferences = Preferences()
        preferences.conversationTextSize = 26
        #expect(preferences.conversationScale(.actual) == 24.0 / 13)
        preferences.terminalTextSize = 3
        #expect(preferences.terminalTextSize == 9)
        #expect(preferences.terminalFontSize(TextScale.actual.bigger) == 9 * 1.1)
    }

    @Test func savedPreferencesRoundTripAndOldOnesDecode() throws {
        var preferences = Preferences()
        preferences.host = "devbox"
        preferences.sendKey = .commandReturn
        preferences.notifiesFinished = false
        preferences.terminalTextSize = 14
        #expect(try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(preferences)) == preferences)
        let old = try JSONDecoder().decode(
            Preferences.self, from: Data(#"{"sendKey":"shiftReturn","conversationTextSize":99}"#.utf8))
        #expect(old.sendKey == .return)
        #expect(old.conversationTextSize == 24)
        #expect(old.notifiesBlocked)
    }

    @Test func aChangeIsSaved() {
        let storage = InMemoryPreferencesStorage()
        let store = store(storage)
        store.set(\.sendKey, to: .commandReturn)
        #expect(storage.preferences.sendKey == .commandReturn)
        #expect(PreferencesStore(storage: storage).preferences.sendKey == .commandReturn)
    }

    @Test func aValidHostIsSavedForTheNextLaunch() {
        let storage = InMemoryPreferencesStorage()
        let store = store(storage)
        #expect(store.hostText.isEmpty)
        #expect(store.hostNotice == "An alias from ~/.ssh/config. Connected to arch.")
        store.setHostText(" devbox ")
        #expect(storage.preferences.host == "devbox")
        #expect(store.hostNotice == "fabrikater connects to devbox the next time it opens.")
        store.setHostText("")
        #expect(storage.preferences.host == nil)
        #expect(!store.hostIsInvalid)
    }

    @Test func anInvalidHostIsNotSaved() {
        let storage = InMemoryPreferencesStorage()
        let store = store(storage)
        store.setHostText("devbox")
        store.setHostText("-oProxyCommand")
        #expect(store.hostIsInvalid)
        #expect(storage.preferences.host == "devbox")
        #expect(store.hostNotice.hasPrefix("Not an ssh alias"))
    }

    @Test func theEnvironmentsHostIsSaid() {
        let store = PreferencesStore(connectedHost: "ci", hostIsOverridden: true)
        #expect(store.hostNotice == "FABRIKATER_HOST is set, so fabrikater connects to ci.")
    }

    @Test func notificationsFollowTheirKinds() throws {
        let herd = try Herd(snapshotReply: Fixture.data(named: "snapshot.synthetic.json"))
        let notifier = RecordingNotifier()
        let preferences = PreferencesStore()
        let app = AppStore(
            herdUpdates: AsyncStream { $0.finish() }, transcripts: NoTranscripts(), control: FakeControl(),
            notifier: notifier, isAppActive: { false }, preferences: preferences)
        app.apply(.herd(herd))
        func setting(_ status: AgentStatus) -> Herd {
            var changed = herd
            changed.panes = herd.panes.map { pane in
                var pane = pane
                if pane.id == refactor { pane.agentStatus = status }
                return pane
            }
            return changed
        }
        preferences.set(\.notifiesBlocked, to: false)
        app.apply(.herd(setting(.blocked)))
        #expect(notifier.alerts.isEmpty)
        app.apply(.herd(setting(.working)))
        preferences.set(\.playsSound, to: false)
        app.apply(.herd(setting(.done)))
        #expect(notifier.alerts.map(\.body) == ["Finished its turn"])
        #expect(notifier.alerts.map(\.playsSound) == [false])
        preferences.set(\.notifiesFinished, to: false)
        app.apply(.herd(setting(.working)))
        app.apply(.herd(setting(.done)))
        #expect(notifier.alerts.count == 1)
    }
}
