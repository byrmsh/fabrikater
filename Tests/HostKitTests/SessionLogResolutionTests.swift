import FabrikaterCore
import Foundation
import Testing

@testable import HostKit

/// Runs the Codex and pi log-finding prefixes against a fake home directory, as the host would.
@Suite struct SessionLogResolutionTests {
    private let home: URL
    private static let id = "00000000-0000-4000-8000-00000000000a"

    init() throws {
        home = FileManager.default.temporaryDirectory.appending(component: "fabrikater-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    }

    private func touch(_ path: String, age: TimeInterval = 60) throws {
        let file = home.appending(path: path)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{}\n".utf8).write(to: file)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: -age)], ofItemAtPath: file.path)
    }

    /// The path under the fake home the prefix settles on, or nil when it exits as not found.
    private func resolve(_ format: SessionLog.Format, environment: [String: String] = [:]) throws -> String? {
        let log = SessionLog(format: format, session: try #require(SessionID(Self.id)))
        let process = Process()
        process.executableURL = URL(filePath: "/bin/sh")
        process.arguments = ["-c", HostCommand.locate(log) + #"printf '%s' "${f#"$HOME"/}""#]
        process.environment = ["HOME": home.path, "PATH": "/usr/bin:/bin"].merging(environment) { $1 }
        let output = Pipe()
        process.standardOutput = output
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        if process.terminationStatus == HostCommand.notFoundStatus { return nil }
        #expect(process.terminationStatus == 0)
        return String(decoding: data, as: UTF8.self)
    }

    @Test func codexFindsTheRolloutInItsDateDirectory() throws {
        #expect(try resolve(.codex) == nil)
        try touch(".codex/sessions/2026/09/27/rollout-2026-09-27T10-00-00-00000000-0000-4000-8000-00000000000b.jsonl")
        #expect(try resolve(.codex) == nil)
        let path = ".codex/sessions/2026/09/28/rollout-2026-09-28T09-30-00-\(Self.id).jsonl"
        try touch(path)
        #expect(try resolve(.codex) == path)
    }

    @Test func codexHonoursCodexHome() throws {
        let path = "elsewhere/sessions/2026/09/28/rollout-2026-09-28T09-30-00-\(Self.id).jsonl"
        try touch(path)
        #expect(try resolve(.codex, environment: ["CODEX_HOME": home.appending(path: "elsewhere").path]) == path)
    }

    @Test func piFindsTheNewestLogUnderOmpOrPi() throws {
        #expect(try resolve(.pi) == nil)
        let pi = ".pi/agent/sessions/--home-user--/2026-09-27T10-00-00-000Z_\(Self.id).jsonl"
        try touch(pi, age: 120)
        #expect(try resolve(.pi) == pi)
        let omp = ".omp/agent/sessions/-Projects-app/2026-09-28T10-00-00-000Z_\(Self.id).jsonl"
        try touch(omp, age: 10)
        #expect(try resolve(.pi) == omp)
    }
}
