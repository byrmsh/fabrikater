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

    private func log(_ id: String, rows: [String], age: TimeInterval, in folder: URL? = nil) throws {
        let file = (folder ?? project).appending(component: "\(id).jsonl")
        try Data(rows.map { $0 + "\n" }.joined().utf8).write(to: file)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: -age)], ofItemAtPath: file.path)
    }

    private func list(_ id: String) throws -> (status: Int32, lines: [String]) {
        let process = Process()
        process.executableURL = URL(filePath: "/bin/sh")
        process.arguments = ["-c", HostCommand.claudeSessions(try #require(SessionID(id))).remoteScript]
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
}
