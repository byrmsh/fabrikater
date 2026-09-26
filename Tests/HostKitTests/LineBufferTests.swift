import Foundation
import Testing

@testable import HostKit

struct LineBufferTests {
    @Test func holdsAPartialLineUntilItsNewline() {
        var buffer = LineBuffer()
        #expect(buffer.append(Data("one\ntw".utf8)) == ["one"])
        #expect(buffer.append(Data("o\n\nthree".utf8)) == ["two", ""])
        #expect(buffer.flush() == "three")
        #expect(buffer.flush() == nil)
    }

    @Test func keepsAMultiByteCharacterSplitAcrossChunks() {
        var buffer = LineBuffer()
        let bytes = Array("é\n".utf8)
        #expect(buffer.append(Data(bytes[..<1])) == [])
        #expect(buffer.append(Data(bytes[1...])) == ["é"])
    }
}
