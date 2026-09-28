import Testing

@testable import AppModel

struct KeymapTests {
    @Test func noTwoCommandsShareAChord() {
        let chords = Array(Keymap.bindings.values)
        #expect(Set(chords).count == chords.count)
    }

    @Test func commandDigitsReachOnlyTheNeedsYouGroup() {
        let digits = (1...9).map { KeyChord(.character(Character(String($0)))) }
        let bound = Keymap.bindings.filter { digits.contains($0.value) }.keys
        #expect(Set(bound) == Set((1...9).map(AppCommand.selectNeedsYou)))
    }
}
