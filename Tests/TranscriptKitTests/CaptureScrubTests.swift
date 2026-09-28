import Foundation
import Testing

@testable import TranscriptKit

/// `scripts/scrub-claude-log.jq`, which `scripts/capture-fixtures.sh` runs over captured logs, keeps what the parsers
/// read and drops the text.
@Suite(.enabled(if: FileManager.default.isExecutableFile(atPath: "/usr/bin/jq")))
struct CaptureScrubTests {
    private static let script = Fixture.directory.deletingLastPathComponent().deletingLastPathComponent()
        .appending(components: "scripts", "scrub-claude-log.jq")

    private func scrubbed(_ name: String) throws -> Data {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/jq")
        process.arguments = ["-s", "-c", "-f", Self.script.path, Fixture.directory.appending(component: name).path]
        let output = Pipe()
        process.standardOutput = output
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
        return data
    }

    /// What survives scrubbing: the rows' roles, the tools called, and the plan's and changes' shapes.
    private struct Shape: Equatable {
        var roles: [TranscriptEntry.Role]
        var tools: [String]
        var todos: [Todo.Status]
        var changes: Int
        var model: String?

        init(_ transcript: Transcript) {
            roles = transcript.entries.map(\.role)
            tools = transcript.entries.flatMap(\.parts).compactMap {
                if case .tool(let call) = $0 { call.name } else { nil }
            }
            todos = transcript.todos.map(\.status)
            changes = transcript.changes.count
            model = transcript.facts.model
        }
    }

    @Test(arguments: [
        "claude.synthetic.jsonl", "claude-todos.synthetic.jsonl", "claude-changes.synthetic.jsonl",
        "claude-facts.synthetic.jsonl", "claude-long.synthetic.jsonl", "claude-markdown.synthetic.jsonl",
    ])
    func scrubbingKeepsTheShape(_ name: String) throws {
        let original = Transcript(claudeLog: try Fixture.data(named: name), window: .max)
        let scrubbed = Transcript(claudeLog: try scrubbed(name), window: .max)
        #expect(Shape(scrubbed) == Shape(original))
    }

    @Test func scrubbingDropsTheText() throws {
        let text = String(decoding: try scrubbed("claude-changes.synthetic.jsonl"), as: UTF8.self)
        for original in ["retries", "Uploader", "/home/user/project/Config.swift"] {
            #expect(!text.contains(original))
        }
    }
}
