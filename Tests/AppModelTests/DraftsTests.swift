import FabrikaterCore
import Foundation
import HerdrKit
import Testing
import TranscriptKit

@testable import AppModel

@MainActor
struct DraftsTests {
    private struct NoTranscripts: TranscriptService {
        func claudeTranscript(session: SessionID, bytes: Int) async throws -> Transcript { Transcript(entries: []) }
    }

    private let refactor = PaneID("w1:p1")!
    private let scratch = PaneID("w2:p1")!

    private func makeStore(_ storage: any DraftStorage, control: FakeControl = FakeControl()) throws -> AppStore {
        let store = AppStore(
            herdUpdates: AsyncStream { $0.finish() }, transcripts: NoTranscripts(), control: control, drafts: storage)
        store.apply(.herd(try Herd(snapshotReply: Fixture.data(named: "snapshot.synthetic.json"))))
        return store
    }

    @Test func aDraftSurvivesARelaunch() throws {
        let storage = InMemoryDraftStorage()
        let first = try makeStore(storage)
        first.perform(.selectPane(refactor))
        first.composer.draft = "half a thought"

        let second = try makeStore(storage)
        second.perform(.selectPane(refactor))
        #expect(second.composer.draft == "half a thought")
        second.perform(.selectPane(scratch))
        #expect(second.composer.draft.isEmpty)
    }

    @Test func aSentDraftIsGoneAfterARelaunch() async throws {
        let storage = InMemoryDraftStorage()
        let store = try makeStore(storage)
        store.perform(.selectPane(refactor))
        store.composer.draft = "run the tests"
        store.perform(.send)
        await store.composer.sendTask?.value
        #expect(storage.load().isEmpty)
    }

    @Test func aPaneWindowSharesThePanesDraft() throws {
        let store = try makeStore(InMemoryDraftStorage())
        store.perform(.selectPane(refactor))
        store.composer.draft = "shared"
        let window = store.paneWindow(refactor)
        #expect(window.composer.draft == "shared")
        window.composer.draft = "shared, edited"
        #expect(store.composer.draft == "shared, edited")
    }

    @Test func emptyDraftsAreNotKept() {
        let storage = InMemoryDraftStorage([refactor: ""])
        let drafts = Drafts(storage: storage)
        drafts[scratch] = "x"
        drafts[scratch] = ""
        #expect(storage.load().isEmpty)
        #expect(drafts[refactor].isEmpty)
    }

    @Test func userDefaultsKeepsDraftsAndSkipsInvalidIDs() throws {
        let suite = "fabrikater-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let storage = UserDefaultsDraftStorage(defaults: defaults)
        storage.save([refactor: "line one\nline two"])
        #expect(UserDefaultsDraftStorage(defaults: defaults).load() == [refactor: "line one\nline two"])
        defaults.set(["not a pane": "x", "w2:p1": "kept"], forKey: "composerDrafts")
        #expect(storage.load() == [scratch: "kept"])
    }
}
