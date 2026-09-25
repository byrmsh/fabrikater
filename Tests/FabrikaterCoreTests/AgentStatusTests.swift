import Foundation
import Testing

@testable import FabrikaterCore

struct AgentStatusTests {
    @Test(arguments: AgentStatus.allCases)
    func roundTripsKnownStatuses(_ status: AgentStatus) throws {
        let data = try JSONEncoder().encode([status])
        #expect(try JSONDecoder().decode([AgentStatus].self, from: data) == [status])
    }

    @Test func mapsStatusesFromNewerHerdrToUnknown() throws {
        let decoded = try JSONDecoder().decode([AgentStatus].self, from: Data(#"["sleeping"]"#.utf8))
        #expect(decoded == [.unknown])
    }
}
