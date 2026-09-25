import Foundation
import Testing

@testable import FabrikaterCore

struct AgentKindTests {
    @Test(arguments: [
        ("claude", AgentKind.claude), ("codex", .codex), ("pi", .pi), ("omp", .omp), ("opencode", .opencode),
        ("grok", .grok),
    ])
    func decodesKnownAgents(_ raw: String, _ expected: AgentKind) throws {
        let decoded = try JSONDecoder().decode([AgentKind].self, from: Data(#"["\#(raw)"]"#.utf8))
        #expect(decoded == [expected])
        #expect(expected.rawValue == raw)
    }

    @Test func keepsUnknownAgentsVerbatim() throws {
        let decoded = try JSONDecoder().decode([AgentKind].self, from: Data(#"["aider"]"#.utf8))
        #expect(decoded == [.other("aider")])
        #expect(try JSONEncoder().encode(decoded) == Data(#"["aider"]"#.utf8))
    }

    @Test func matchesExactlyNotByPrefix() {
        #expect(AgentKind(rawValue: "claude-code") == .other("claude-code"))
        #expect(AgentKind(rawValue: "Claude") == .other("Claude"))
    }
}
