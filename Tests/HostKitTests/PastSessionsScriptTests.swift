import FabrikaterCore
import Foundation
import Testing

@testable import HostKit

/// Runs the Past Sessions listing against a fake home directory, as the host would.
@Suite struct PastSessionsScriptTests {
    private let home: URL
    private let project: URL

    init() throws {
        home = FileManager.default.temporaryDirectory.appending(component: "fabrikater-\(UUID().uuidString)")
        project = home.appending(components: ".claude", "projects", "-home-user-app")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
    }

    private static let a = "00000000-0000-4000-8000-00000000000a"
    private static let b = "00000000-0000-4000-8000-00000000000b"
    private static let c = "00000000-0000-4000-8000-00000000000c"

    private func log(
        _ id: String, rows: [String], age: TimeInterval, in folder: URL? = nil, name: String? = nil
    ) throws {
        let folder = folder ?? project
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appending(component: name ?? "\(id).jsonl")
        try Data(rows.map { $0 + "\n" }.joined().utf8).write(to: file)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: -age)], ofItemAtPath: file.path)
    }

    private func list(_ id: String, format: SessionLog.Format = .claude) throws -> (status: Int32, lines: [String]) {
        let log = SessionLog(format: format, session: try #require(SessionID(id)))
        let process = Process()
        process.executableURL = URL(filePath: "/bin/sh")
        process.arguments = ["-c", HostCommand.sessions(log).remoteScript]
        process.environment = ["HOME": home.path, "PATH": "/usr/bin:/bin"]
        let output = Pipe()
        process.standardOutput = output
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let lines = String(decoding: data, as: UTF8.self).split(separator: "\n").map(String.init)
        return (process.terminationStatus, lines)
    }

    @Test func aSessionWithoutALogIsNotFound() throws {
        #expect(try list(Self.a).status == HostCommand.notFoundStatus)
    }

    @Test func listsEveryLogInTheFolderNewestFirstAfterTheLiveOne() throws {
        let prompt = #"{"type":"user","uuid":"u1","message":{"role":"user","content":"Build it"}}"#
        try log(Self.a, rows: [prompt], age: 300)
        try log(Self.b, rows: [#"{"type":"user","uuid":"u2","message":{"role":"user","content":"Other"}}"#], age: 10)
        let other = home.appending(components: ".claude", "projects", "-home-user-other")
        try FileManager.default.createDirectory(at: other, withIntermediateDirectories: true)
        try log(Self.c, rows: [prompt], age: 1, in: other)

        let (status, lines) = try list(Self.a)
        #expect(status == 0)
        #expect(lines.first == "\(Self.a).jsonl")
        let records = lines.dropFirst().map { $0.split(separator: "\t", omittingEmptySubsequences: false) }
        #expect(records.map { String($0[2]) } == ["\(Self.b).jsonl", "\(Self.a).jsonl"])
        #expect(records.last?[1] == "\(prompt.utf8.count + 1)")
        let seconds = try #require(records.last.flatMap { TimeInterval(String($0[0])) })
        #expect(abs(seconds - Date(timeIntervalSinceNow: -300).timeIntervalSince1970) < 5)
        #expect(records.last?[3] == Substring(prompt))
    }

    @Test func printsOnlyUserRowsThatCarryAPrompt() throws {
        let rows = [
            #"{"type":"permission-mode","permissionMode":"default"}"#,
            #"{"type":"user","uuid":"u0","message":{"role":"user","content":"<command-name>/clear</command-name>"}}"#,
            #"{"type":"user","uuid":"u1","isMeta":true,"message":{"role":"user","content":"Skill text"}}"#,
            #"{"type":"user","uuid":"u2","isSidechain":true,"message":{"role":"user","content":"Subagent"}}"#,
            #"{"type":"user","uuid":"u3","message":{"role":"user","content":[{"type":"text","text":"<system-reminder>x"}]}}"#,
            #"{"type":"user","uuid":"u4","message":{"role":"user","content":"First"}}"#,
            #"{"type":"user","uuid":"u5","message":{"role":"user","content":[{"type":"tool_result","content":"ok"}]}}"#,
            #"{"type":"user","uuid":"u6","message":{"role":"user","content":"Second"}}"#,
            #"{"type":"user","uuid":"u7","message":{"role":"user","content":"Third"}}"#,
            #"{"type":"user","uuid":"u8","message":{"role":"user","content":"Fourth"}}"#,
        ]
        try log(Self.a, rows: rows, age: 60)
        let fields = try list(Self.a).lines[1].split(separator: "\t").dropFirst(3)
        #expect(
            fields.map { $0.contains("uuid\":\"u") ? String($0.split(separator: "\"")[7]) : "" } == ["u4", "u6", "u7"])
    }

    @Test func cutsALongRow() throws {
        let long =
            #"{"type":"user","message":{"role":"user","content":""# + String(repeating: "a", count: 20_000) + #""}}"#
        try log(Self.a, rows: [long], age: 60)
        #expect(try list(Self.a).lines[1].split(separator: "\t")[3].utf8.count == 8192)
    }

    @Test func listsAPiLogsFolderByItsUserMessages() throws {
        let folder = home.appending(components: ".pi", "agent", "sessions", "--home-user-app--")
        let prompt = #"{"type":"message","id":"p1","message":{"role":"user","content":[{"type":"text","text":"Hi"}]}}"#
        let rows = [#"{"type":"session","version":3,"id":"x"}"#, prompt]
        try log(Self.a, rows: rows, age: 60, in: folder, name: "2026-09-27T10-00-00-000Z_\(Self.a).jsonl")
        try log(Self.b, rows: rows, age: 10, in: folder, name: "2026-09-28T10-00-00-000Z_\(Self.b).jsonl")

        let (status, lines) = try list(Self.a, format: .pi)
        #expect(status == 0)
        #expect(lines.first == "2026-09-27T10-00-00-000Z_\(Self.a).jsonl")
        let records = lines.dropFirst().map { $0.split(separator: "\t", omittingEmptySubsequences: false) }
        #expect(records.map { String($0[2]).hasSuffix("\(Self.b).jsonl") } == [true, false])
        #expect(records.map { $0.dropFirst(3).map(String.init) } == [[prompt], [prompt]])
    }

    @Test func listsTheCodexRolloutsOfTheLiveOnesWorkingDirectory() throws {
        let sessions = home.appending(components: ".codex", "sessions")
        func rollout(_ id: String, cwd: String, day: String, age: TimeInterval) throws {
            let rows = [
                #"{"type":"session_meta","payload":{"id":"\#(id)","cwd":"\#(cwd)"}}"#,
                #"{"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"<environment_context>"}]}}"#,
                #"{"type":"event_msg","payload":{"type":"user_message","message":"Prompt \#(id.suffix(1))"}}"#,
            ]
            try log(
                id, rows: rows, age: age, in: sessions.appending(components: "2026", "09", day),
                name: "rollout-2026-09-\(day)T10-00-00-\(id).jsonl")
        }
        try rollout(Self.a, cwd: "/home/user/app", day: "27", age: 60)
        try rollout(Self.b, cwd: "/home/user/other", day: "28", age: 10)
        try rollout(Self.c, cwd: "/home/user/app", day: "20", age: 600)

        let (status, lines) = try list(Self.a, format: .codex)
        #expect(status == 0)
        #expect(lines.first == "rollout-2026-09-27T10-00-00-\(Self.a).jsonl")
        let records = lines.dropFirst().map { $0.split(separator: "\t", omittingEmptySubsequences: false) }
        #expect(records.map { String($0[2]) } == [lines[0], "rollout-2026-09-20T10-00-00-\(Self.c).jsonl"])
        #expect(records.map { $0.count } == [4, 4])
        #expect(records.last?[3].contains("Prompt c") == true)
    }

    @Test func aCodexSessionWithoutARolloutIsNotFound() throws {
        #expect(try list(Self.a, format: .codex).status == HostCommand.notFoundStatus)
    }
}
