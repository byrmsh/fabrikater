import Foundation
import Testing

@testable import FabrikaterCore

struct SessionIDTests {
    @Test(arguments: [
        "00000000-0000-4000-8000-000000000019", "01A0D30E-ABCD-7000-8000-0123456789AB", "ses_abcDEF12",
        "ses_" + String(repeating: "a", count: 64),
    ])
    func acceptsValidIDs(_ raw: String) {
        #expect(SessionID(raw)?.rawValue == raw)
    }

    @Test(arguments: [
        "", "00000000-0000-4000-8000-00000000001", "00000000-0000-4000-8000-00000000001g",
        "00000000000040008000000000000019", "00000000-0000-4000-8000-000000000019'; rm -rf ~",
        "ses_short", "ses_" + String(repeating: "a", count: 65), "ses_abc-def12", "../00000000-0000-4000-8000-0000",
    ])
    func rejectsInvalidIDs(_ raw: String) {
        #expect(SessionID(raw) == nil)
    }

    @Test func decodesOnlyValidIDs() throws {
        let log = SessionLog(format: .claude, session: try #require(SessionID("00000000-0000-4000-8000-000000000019")))
        let data = try JSONEncoder().encode(log)
        #expect(try JSONDecoder().decode(SessionLog.self, from: data) == log)
        let forged = Data(#"{"format":"claude","session":"../etc; rm -rf ~"}"#.utf8)
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(SessionLog.self, from: forged) }
    }
}
