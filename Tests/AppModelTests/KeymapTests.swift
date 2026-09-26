import Testing

@testable import AppModel

struct KeymapTests {
    @Test func noTwoCommandsShareAChord() {
        let chords = Array(Keymap.bindings.values)
        #expect(Set(chords).count == chords.count)
    }

    @Test func theNeedsYouRangeIsFree() {
        let digits = (1...9).map { KeyChord(.character(Character(String($0)))) }
        #expect(Keymap.bindings.values.allSatisfy { !digits.contains($0) })
    }
}
