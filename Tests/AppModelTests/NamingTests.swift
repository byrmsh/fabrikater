import FabrikaterCore
import Foundation
import HerdrKit
import Testing
import TranscriptKit

@testable import AppModel

@MainActor
struct NamingTests {
    private struct NoTranscripts: TranscriptService {
        func claudeTranscript(session: SessionID, bytes: Int) async throws -> Transcript { Transcript() }
    }

    private let scratch = PaneID("w2:p1")!
    private let refactor = PaneID("w1:p1")!

    private func makeStore(_ notes: any PaneNotesStore = InMemoryPaneNotesStore()) throws -> AppStore {
        let herd = try Herd(snapshotReply: Fixture.data(named: "snapshot.synthetic.json"))
        let store = AppStore(
            herdUpdates: AsyncStream { $0.finish() }, transcripts: NoTranscripts(), control: FakeControl(), notes: notes
        )
        store.apply(.herd(herd))
        return store
    }

    private func label(_ id: PaneID, in store: AppStore) -> String? {
        store.sections.flatMap { $0.rows.flatMap(\.panes) }.first { $0.id == id }?.label
    }

    private func rename(_ id: PaneID, to text: String, in store: AppStore) {
        store.perform(.renamePane(id))
        store.perform(.commitRename(id, text))
    }

    @Test func aNamedPaneShowsItsNameInTheRowAndHeader() throws {
        let store = try makeStore()
        store.perform(.selectPane(scratch))
        rename(scratch, to: "  Release notes ", in: store)
        #expect(label(scratch, in: store) == "Release notes")
        #expect(store.header?.title == "Release notes")
        #expect(store.renaming == nil)
    }

    @Test func aPaneInsideATabIsNamedToo() throws {
        let store = try makeStore()
        rename(refactor, to: "API work", in: store)
        #expect(label(refactor, in: store) == "API work")
    }

    @Test func clearingTheNameRestoresTheHerdrLabel() throws {
        let store = try makeStore()
        store.perform(.selectPane(scratch))
        rename(scratch, to: "Release notes", in: store)
        rename(scratch, to: "   ", in: store)
        #expect(label(scratch, in: store) == "Scratch")
        #expect(store.header?.title == "Scratch")
    }

    @Test func cancellingKeepsTheName() throws {
        let store = try makeStore()
        store.perform(.renamePane(scratch))
        store.perform(.cancelRename)
        store.perform(.commitRename(scratch, "Ignored"))
        #expect(store.renaming == nil)
        #expect(label(scratch, in: store) == "Scratch")
    }

    @Test func renameWithoutAPaneActsOnTheSelection() throws {
        let store = try makeStore()
        #expect(!store.isEnabled(.renamePane(nil)))
        store.perform(.selectPane(scratch))
        #expect(store.isEnabled(.renamePane(nil)))
        store.perform(.renamePane(nil))
        #expect(store.renaming == scratch)
    }

    @Test func unchangedTextStoresNoName() throws {
        let notes = InMemoryPaneNotesStore()
        let store = try makeStore(notes)
        rename(scratch, to: "Scratch", in: store)
        #expect(notes.load().names.isEmpty)
    }

    @Test func aNameForAVanishedPaneIsKeptButUnused() throws {
        let gone = PaneID("w9:p9")!
        let notes = InMemoryPaneNotesStore(PaneNotes(names: [gone: "Old"]))
        let store = try makeStore(notes)
        #expect(!store.sections.flatMap { $0.rows.flatMap(\.panes) }.map(\.label).contains("Old"))
        rename(scratch, to: "New", in: store)
        #expect(notes.load().names == [gone: "Old", scratch: "New"])
    }

    @Test func namesAreLoadedAtLaunch() throws {
        let store = try makeStore(InMemoryPaneNotesStore(PaneNotes(names: [scratch: "Saved"])))
        #expect(label(scratch, in: store) == "Saved")
    }

    @Test func theUserDefaultsStoreRoundTrips() throws {
        let suite = "fabrikater.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let notes = PaneNotes(names: [scratch: "Release notes"])

        UserDefaultsPaneNotesStore(defaults: defaults).save(notes)
        #expect(UserDefaultsPaneNotesStore(defaults: defaults).load() == notes)
    }

    @Test func unreadableNotesLoadEmpty() throws {
        let suite = "fabrikater.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data("not json".utf8), forKey: "paneNotes")
        #expect(UserDefaultsPaneNotesStore(defaults: defaults).load() == PaneNotes())
    }

    @Test func notesWithoutANamesFieldDecode() throws {
        let notes = try JSONDecoder().decode(PaneNotes.self, from: Data("{}".utf8))
        #expect(notes == PaneNotes())
    }
}
