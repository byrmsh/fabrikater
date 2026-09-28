import FabrikaterCore
import HerdrKit
import Testing
import TranscriptKit

@testable import AppModel

@MainActor
struct ChangesPanelTests {
    private struct FixedTranscripts: TranscriptService {
        let transcript: Transcript

        func claudeTranscript(session: SessionID, bytes: Int) async throws -> Transcript { transcript }
    }

    private let file = FileChange(
        path: "/home/user/project/a.swift",
        edits: [FileEdit(id: "t1", kind: .edit, lines: [DiffLine(.removed, "a"), DiffLine(.added, "b")])])

    private func makeStore(_ transcript: Transcript) async throws -> AppStore {
        let store = AppStore(
            herdUpdates: AsyncStream { $0.finish() }, transcripts: FixedTranscripts(transcript: transcript),
            control: FakeControl())
        store.apply(.herd(try Herd(snapshotReply: Fixture.data(named: "snapshot.synthetic.json"))))
        store.perform(.selectPane(PaneID("w2:p1")!))
        await store.conversation.loadTask?.value
        return store
    }

    @Test func listsTheSessionsChangedFiles() async throws {
        let store = try await makeStore(Transcript(entries: [], changes: [file]))
        let panel = store.conversation.changesPanel
        #expect(panel.files == [file])
        #expect(panel.summary == "1 file")
        #expect(panel.footnote == nil)
    }

    @Test func noChangesSaysSo() async throws {
        let panel = try await makeStore(Transcript()).conversation.changesPanel
        #expect(panel.files.isEmpty)
        #expect(panel.emptyTitle == "No Changes")
        #expect(panel.summary == "0 files")
    }

    @Test func aClippedLogWarnsThatOlderChangesMayBeMissing() async throws {
        let panel = try await makeStore(Transcript(isClipped: true, changes: [file, file])).conversation.changesPanel
        #expect(panel.footnote != nil)
        #expect(panel.summary == "2 files")
    }

    @Test func aFirstLoadSaysItIsLoading() {
        let panel = ChangesPanel(transcript: Transcript(), isLoading: true)
        #expect(panel.emptyTitle == "Loading Changes")
    }

    @Test func theToggleOpensAndClosesTheInspector() async throws {
        let store = try await makeStore(Transcript())
        #expect(store.isEnabled(.toggleChanges))
        #expect(store.isChecked(.toggleChanges) == false)
        store.perform(.toggleChanges)
        #expect(store.isShowingChanges)
        #expect(store.isChecked(.toggleChanges) == true)
        store.perform(.setChangesShown(false))
        #expect(!store.isShowingChanges)
    }

    @Test func copyPathPutsThePathOnTheClipboard() async throws {
        let clipboard = InMemoryClipboard()
        let store = AppStore(
            herdUpdates: AsyncStream { $0.finish() }, transcripts: FixedTranscripts(transcript: Transcript()),
            control: FakeControl(), clipboard: clipboard)
        store.perform(.copyPath(file.path))
        #expect(clipboard.text == file.path)
    }

    @Test func withNoPaneSelectedTheToggleIsDisabled() {
        let store = AppStore(
            herdUpdates: AsyncStream { $0.finish() }, transcripts: FixedTranscripts(transcript: Transcript()),
            control: FakeControl())
        #expect(!store.isEnabled(.toggleChanges))
    }
}
