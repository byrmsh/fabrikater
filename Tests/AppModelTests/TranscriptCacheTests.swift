import FabrikaterCore
import Testing
import TranscriptKit

@testable import AppModel

struct TranscriptCacheTests {
    private let sessions = (1...3).map {
        SessionLog(format: .claude, session: SessionID("00000000-0000-4000-8000-00000000000\($0)")!)
    }

    @Test func dropsTheLeastRecentlyStoredPastTheLimit() {
        var cache = TranscriptCache(limit: 2)
        for session in sessions { cache.store(Transcript(), for: session) }
        #expect(cache[sessions[0]] == nil)
        #expect(cache[sessions[1]] != nil)
        #expect(cache[sessions[2]] != nil)
    }

    @Test func storingAgainMakesASessionRecent() {
        var cache = TranscriptCache(limit: 2)
        cache.store(Transcript(), for: sessions[0])
        cache.store(Transcript(), for: sessions[1])
        cache.store(Transcript(isClipped: true), for: sessions[0])
        cache.store(Transcript(), for: sessions[2])
        #expect(cache[sessions[0]]?.isClipped == true)
        #expect(cache[sessions[1]] == nil)
    }
}
