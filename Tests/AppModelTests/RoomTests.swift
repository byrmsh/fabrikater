import FabrikaterCore
import HerdrKit
import Testing
import TranscriptKit

@testable import AppModel

struct TextScaleTests {
    @Test func stepsClampAtBothEnds() {
        var scale = TextScale.actual
        for _ in 0..<20 { scale = scale.bigger }
        #expect(scale.isLargest)
        #expect(scale.factor == TextScale.factors.last)
        #expect(scale.bigger == scale)
        for _ in 0..<20 { scale = scale.smaller }
        #expect(scale.isSmallest)
        #expect(scale.factor == TextScale.factors.first)
        #expect(scale.smaller == scale)
    }

    @Test func actualSizeIsTheSystemSize() {
        #expect(TextScale.actual.factor == 1.0)
        #expect(TextScale.actual.bigger.smaller == .actual)
    }

    @Test func aSavedStepOutOfRangeLandsOnTheNearestStep() {
        #expect(TextScale(step: -3) == TextScale(step: 0))
        #expect(TextScale(step: 99).isLargest)
    }
}

@MainActor
struct RoomTests {
    private struct NoTranscripts: TranscriptService {
        func transcript(of log: SessionLog, bytes: Int) async throws -> Transcript { Transcript() }
    }

    private func makeStore() -> AppStore {
        AppStore(herdUpdates: AsyncStream { $0.finish() }, transcripts: NoTranscripts(), control: FakeControl())
    }

    @Test func textSizeStepsAndResets() {
        let store = makeStore()
        #expect(!store.isEnabled(.actualSizeText))
        store.perform(.biggerText)
        store.perform(.biggerText)
        #expect(store.textScale == TextScale.actual.bigger.bigger)
        #expect(store.isEnabled(.actualSizeText))
        store.perform(.actualSizeText)
        #expect(store.textScale == .actual)
        store.perform(.smallerText)
        #expect(store.textScale == TextScale.actual.smaller)
    }

    @Test func biggerAndSmallerDisableAtTheEnds() {
        let store = makeStore()
        store.perform(.setTextScale(TextScale(step: 99)))
        #expect(!store.isEnabled(.biggerText))
        #expect(store.isEnabled(.smallerText))
        store.perform(.setTextScale(TextScale(step: 0)))
        #expect(!store.isEnabled(.smallerText))
        #expect(store.isEnabled(.biggerText))
    }

    @Test func theSidebarToggles() {
        let store = makeStore()
        #expect(store.isSidebarVisible)
        store.perform(.toggleSidebar)
        #expect(!store.isSidebarVisible)
        store.perform(.setSidebarVisible(true))
        #expect(store.isSidebarVisible)
    }

    @Test func theHeaderStillCarriesStatusAndAgent() throws {
        let store = makeStore()
        store.apply(.herd(try Herd(snapshotReply: Fixture.data(named: "snapshot.synthetic.json"))))
        store.perform(.selectPane(PaneID("w1:p1")!))
        #expect(store.header?.agent == "Claude")
        #expect(store.header?.status == .working)
    }
}
