import FabrikaterCore
import Foundation
import HerdrKit
import Testing
import TranscriptKit

@testable import AppModel

@MainActor
struct PanelLayoutTests {
    private struct FixedTranscripts: TranscriptService {
        let transcript: Transcript

        func transcript(of log: SessionLog, bytes: Int) async throws -> Transcript { transcript }
    }

    private func applying(_ commands: AppCommand...) -> PanelLayout {
        var layout = PanelLayout.standard
        for command in commands {
            layout.apply(command)
            #expect(Set(layout.order) == Set(InfoPanel.allCases) && layout.order.count == InfoPanel.allCases.count)
        }
        return layout
    }

    @Test func theStandardLayoutShowsThePlanAboveTheConversation() {
        let layout = PanelLayout.standard
        #expect(layout.panels(in: .top) == [.plan])
        #expect(layout.panels(in: .trailing).isEmpty)
        #expect(layout.dock(of: .changes) == .trailing)
        #expect(layout.dock(of: .facts) == .trailing)
    }

    @Test func togglingShowsAndHidesAPanelInItsDock() {
        let layout = applying(.togglePanel(.facts), .togglePanel(.changes))
        #expect(layout.panels(in: .trailing) == [.changes, .facts])
        #expect(applying(.togglePanel(.plan)).panels(in: .top).isEmpty)
    }

    @Test func closingADockHidesOnlyItsPanels() {
        let layout = applying(.togglePanel(.changes), .togglePanel(.facts), .hidePanels(.trailing))
        #expect(layout.shown == [.plan])
    }

    @Test func movingAPanelShowsItLastInItsNewDock() {
        let layout = applying(.togglePanel(.changes), .movePanel(.plan, to: .trailing))
        #expect(layout.panels(in: .top).isEmpty)
        #expect(layout.panels(in: .trailing) == [.changes, .plan])
        #expect(layout.isChecked(.movePanel(.plan, to: .trailing)) == true)
        #expect(layout.isChecked(.movePanel(.plan, to: .top)) == false)

        let hidden = applying(.movePanel(.facts, to: .leading))
        #expect(hidden.panels(in: .leading) == [.facts])
    }

    @Test func movingUpAndDownSwapsWithTheNextShownPanelInTheDock() {
        var layout = applying(.togglePanel(.changes), .togglePanel(.facts))
        #expect(!layout.canApply(.movePanelUp(.changes)))
        #expect(!layout.canApply(.movePanelDown(.facts)))
        layout.apply(.movePanelUp(.facts))
        #expect(layout.panels(in: .trailing) == [.facts, .changes])
        layout.apply(.movePanelDown(.facts))
        #expect(layout.panels(in: .trailing) == [.changes, .facts])

        // The plan sits between them in the order but in another dock, so it is skipped.
        var split = applying(.movePanel(.changes, to: .leading), .movePanel(.plan, to: .leading))
        split.apply(.togglePanel(.facts))
        split.apply(.movePanel(.facts, to: .leading))
        #expect(split.panels(in: .leading) == [.changes, .plan, .facts])
        split.apply(.movePanelUp(.facts))
        #expect(split.panels(in: .leading) == [.changes, .facts, .plan])
    }

    @Test func resetGoesBackToTheStandardLayout() {
        var layout = applying(.movePanel(.plan, to: .leading))
        #expect(layout.canApply(.resetPanels))
        layout.apply(.resetPanels)
        #expect(layout == .standard)
        #expect(!layout.canApply(.resetPanels))
    }

    @Test func aSavedLayoutRoundTripsAndABrokenOneFallsBack() throws {
        let suite = "fabrikater-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let storage = UserDefaultsPanelLayoutStorage(defaults: defaults)
        #expect(storage.load() == .standard)

        let moved = applying(.movePanel(.plan, to: .leading), .togglePanel(.changes))
        storage.save(moved)
        #expect(UserDefaultsPanelLayoutStorage(defaults: defaults).load() == moved)

        defaults.set(Data("not json".utf8), forKey: "panelLayout")
        #expect(storage.load() == .standard)
    }

    @Test func aSavedLayoutMissingAPanelGetsItBack() throws {
        let suite = "fabrikater-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let json = #"{"order":["facts","plan"],"docks":{"plan":"leading"},"shown":["plan"]}"#
        defaults.set(Data(json.utf8), forKey: "panelLayout")
        let layout = UserDefaultsPanelLayoutStorage(defaults: defaults).load()
        #expect(layout.order == [.facts, .plan, .changes])
        #expect(layout.dock(of: .plan) == .leading)
        #expect(layout.dock(of: .changes) == .trailing)
    }

    @Test func aNewWindowStartsFromTheLastChange() throws {
        let storage = InMemoryPanelLayoutStorage()
        let store = AppStore(
            herdUpdates: AsyncStream { $0.finish() }, transcripts: FixedTranscripts(transcript: Transcript()),
            control: FakeControl(), panelLayouts: storage)
        store.apply(.herd(try Herd(snapshotReply: Fixture.data(named: "snapshot.synthetic.json"))))
        store.perform(.selectPane(PaneID("w1:p1")!))
        store.perform(.movePanel(.facts, to: .leading))
        #expect(storage.load().panels(in: .leading) == [.facts])

        let window = store.paneWindow(PaneID("w2:p1")!)
        #expect(window.panels.panels(in: .leading) == [.facts])
        window.perform(.resetPanels)
        #expect(store.panels.panels(in: .leading) == [.facts])
        #expect(storage.load() == .standard)
    }

    @Test func thePlanLeavesItsDockWhenTheSessionHasNone() async throws {
        let todo = Todo(content: "Write the tests", status: .inProgress)
        for (todos, panels) in [([todo], [InfoPanel.plan]), ([], [])] {
            let store = AppStore(
                herdUpdates: AsyncStream { $0.finish() },
                transcripts: FixedTranscripts(transcript: Transcript(todos: todos)), control: FakeControl())
            store.apply(.herd(try Herd(snapshotReply: Fixture.data(named: "snapshot.synthetic.json"))))
            store.perform(.selectPane(PaneID("w2:p1")!))
            await store.conversation.loadTask?.value
            #expect(store.detail.panels(in: .top) == panels)
        }
    }

    @Test func movingNeedsNoPaneButShowingDoes() {
        let store = AppStore(
            herdUpdates: AsyncStream { $0.finish() }, transcripts: FixedTranscripts(transcript: Transcript()),
            control: FakeControl())
        #expect(!store.isEnabled(.togglePanel(.plan)))
        #expect(store.isEnabled(.movePanel(.plan, to: .leading)))
        #expect(!store.isEnabled(.movePanel(.plan, to: .top)))
        #expect(!store.isEnabled(.resetPanels))
    }

    @Test func panelShortcutsAreKept() {
        #expect(Keymap.chord(for: .togglePanel(.changes)) == KeyChord(.character("0"), [.command, .option]))
        #expect(Keymap.chord(for: .togglePanel(.facts)) == KeyChord(.character("i")))
    }
}
