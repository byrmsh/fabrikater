import Foundation
import Testing

@testable import FabrikaterCore

struct PaneIDTests {
    @Test(arguments: ["w3:pQ", "w1:p1", "w10:pAbC9", "wZ:p0"])
    func acceptsValidIDs(_ raw: String) {
        #expect(PaneID(raw)?.rawValue == raw)
    }

    @Test(arguments: [
        "", "w3", "w3:", ":pQ", "w:pQ", "w3:p", "x3:pQ", "w3:qQ", "w3:pQ:pR", "W3:pQ", "w3:p-Q", "w3:p Q",
        "w3:pQ\n", "w3:pQ;rm", "w3:p'Q'", "w3:pé", "w３:pQ",
    ])
    func rejectsInvalidIDs(_ raw: String) {
        #expect(PaneID(raw) == nil)
    }

    @Test func roundTripsThroughJSON() throws {
        let id = try #require(PaneID("w3:pQ"))
        let data = try JSONEncoder().encode([id])
        #expect(String(decoding: data, as: UTF8.self) == #"["w3:pQ"]"#)
        #expect(try JSONDecoder().decode([PaneID].self, from: data) == [id])
    }

    @Test func decodingAnInvalidIDThrows() {
        let data = Data(#"["w3:pQ; rm -rf ~"]"#.utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode([PaneID].self, from: data)
        }
    }
}
