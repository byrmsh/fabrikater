import FabrikaterCore
import HerdrKit
import Testing
import TranscriptKit

@testable import AppModel

@MainActor
struct MenuTargetTests {
    private struct EmptyTranscripts: TranscriptService {
        func claudeTranscript(session: SessionID, bytes: Int) async throws -> Transcript { Transcript() }
    }

    private let clipboard = InMemoryClipboard()
    private let opener = RecordingURLOpener()
    private let refactor = PaneID("w1:p1")!
    private let scratch = PaneID("w2:p1")!

    private func makeStore() throws -> AppStore {
        let store = AppStore(
            herdUpdates: AsyncStream { $0.finish() }, transcripts: EmptyTranscripts(), control: FakeControl(),
            clipboard: clipboard, opener: opener)
        store.apply(.herd(try Herd(snapshotReply: Fixture.data(named: "snapshot.synthetic.json"))))
        store.perform(.selectPane(scratch))
        return store
    }

    @Test func withTheMainWindowInFrontEveryCommandGoesToIt() throws {
        let store = try makeStore()
        let target = MenuTarget(app: store, window: nil)
        target.perform(.toggleChanges)
        #expect(store.panels.isShowingChanges)
        #expect(target.isChecked(.toggleChanges) == true)
        #expect(target.windowPane == scratch)
        #expect(target.route(.renamePane(nil)) == .app(.renamePane(nil)))
    }

    @Test func aPaneWindowInFrontGetsItsOwnPanels() throws {
        let store = try makeStore()
        let window = store.paneWindow(refactor)
        let target = MenuTarget(app: store, window: window)

        target.perform(.toggleChanges)
        #expect(window.panels.isShowingChanges)
        #expect(!store.panels.isShowingChanges)
        #expect(target.isChecked(.toggleChanges) == true)
        #expect(MenuTarget(app: store, window: nil).isChecked(.toggleChanges) == false)

        target.perform(.toggleSessionFacts)
        #expect(window.panels.isShowingSessionFacts)
        #expect(!store.panels.isShowingSessionFacts)
    }

    @Test func aPaneWindowsPaneCommandsNameItsPane() throws {
        let store = try makeStore()
        let target = MenuTarget(app: store, window: store.paneWindow(refactor))

        #expect(target.title(of: .togglePin(nil)) == "Pin")
        target.perform(.togglePin(nil))
        #expect(target.title(of: .togglePin(nil)) == "Unpin")
        #expect(store.title(of: .togglePin(nil)) == "Pin")

        target.perform(.openInVSCode(nil))
        #expect(opener.opened.count == 1)
        #expect(target.windowPane == refactor)
    }

    @Test func aPaneWindowHasNoSidebarToRenameOrHideAWorkspaceIn() throws {
        let store = try makeStore()
        let target = MenuTarget(app: store, window: store.paneWindow(refactor))
        #expect(!target.isEnabled(.renamePane(nil)))
        #expect(!target.isEnabled(.toggleHiddenWorkspace(nil)))
        target.perform(.renamePane(nil))
        #expect(store.renaming == nil)
        #expect(target.isEnabled(.selectNextPane))
    }

    @Test func sendAndReloadInAPaneWindowActOnItsOwnConversation() throws {
        let store = try makeStore()
        let window = store.paneWindow(refactor)
        let target = MenuTarget(app: store, window: window)
        store.composer.draft = "for scratch"
        #expect(!target.isEnabled(.send))
        window.composer.draft = "for refactor"
        #expect(target.isEnabled(.send))
        #expect(target.route(.reloadConversation) == .window(.reloadConversation))
        #expect(target.route(.sendKey(.escape)) == .window(.sendKey(.escape)))
    }
}
