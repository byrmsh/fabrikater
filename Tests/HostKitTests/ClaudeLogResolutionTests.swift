import FabrikaterCore
import Foundation
import Testing

@testable import HostKit

/// Runs the log-finding shell prefix against a fake home directory, as the host would.
@Suite struct ClaudeLogResolutionTests {
    private let home: URL
    private let projects: URL

    init() throws {
        home = FileManager.default.temporaryDirectory.appending(component: "fabrikater-\(UUID().uuidString)")
        projects = home.appending(components: ".claude", "projects")
        try FileManager.default.createDirectory(at: projects, withIntermediateDirectories: true)
    }

    private static let a = "00000000-0000-4000-8000-00000000000a"
    private static let b = "00000000-0000-4000-8000-00000000000b"
    private static let c = "00000000-0000-4000-8000-00000000000c"

    private static let root = #"{"type":"user","uuid":"root-1","message":{"role":"user","content":"Start"}}"#
    private static let otherRoot = #"{"type":"user","uuid":"root-2","message":{"role":"user","content":"Else"}}"#
    private static let reply = #"{"type":"assistant","uuid":"r1","message":{"role":"assistant","content":[]}}"#
    private static let sidechainReply =
        #"{"type":"assistant","isSidechain":true,"uuid":"r2","message":{"role":"assistant","content":[]}}"#
    private static func handOver(to id: String) -> String {
        #"{"type":"continued-in","continuedInSessionId":"\#(id)"}"#
    }

    /// Writes a log of `rows` in `project`, last modified `age` seconds ago.
    private func log(_ id: String, in project: String = "-home-user-app", rows: [String], age: TimeInterval) throws {
        let directory = projects.appending(component: project)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appending(component: "\(id).jsonl")
        try Data(rows.map { $0 + "\n" }.joined().utf8).write(to: file)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: -age)], ofItemAtPath: file.path)
    }

    /// The file name the prefix settles on for `id`, or nil when it exits as not found.
    private func resolve(_ id: String) throws -> String? {
        let session = try #require(SessionID(id))
        let process = Process()
        process.executableURL = URL(filePath: "/bin/sh")
        process.arguments = ["-c", HostCommand.claudeLog(session) + #"printf '%s' "${f##*/}""#]
        process.environment = ["HOME": home.path, "PATH": "/usr/bin:/bin"]
        let output = Pipe()
        process.standardOutput = output
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        if process.terminationStatus == HostCommand.notFoundStatus { return nil }
        #expect(process.terminationStatus == 0)
        return String(decoding: data, as: UTF8.self)
    }

    @Test func aMissingLogIsNotFound() throws {
        #expect(try resolve(Self.a) == nil)
    }

    @Test func aLiveLogIsItself() throws {
        try log(Self.a, rows: [Self.root, Self.reply], age: 60)
        #expect(try resolve(Self.a) == "\(Self.a).jsonl")
    }

    @Test func aHandOverMovesToTheNewLogBesideIt() throws {
        try log(Self.a, rows: [Self.root, Self.reply, Self.handOver(to: Self.b)], age: 60)
        try log(Self.b, rows: [Self.otherRoot, Self.reply], age: 30)
        #expect(try resolve(Self.a) == "\(Self.b).jsonl")
    }

    @Test func aHandOverFollowsIntoAnotherProjectAndOnAgain() throws {
        try log(Self.a, rows: [Self.root, Self.handOver(to: Self.b)], age: 60)
        try log(Self.b, in: "-home-user-other", rows: [Self.otherRoot, Self.handOver(to: Self.c)], age: 30)
        try log(Self.c, rows: [Self.reply], age: 10)
        #expect(try resolve(Self.a) == "\(Self.c).jsonl")
    }

    @Test func anAssistantRowAfterTheHandOverMeansTheLogIsStillLive() throws {
        try log(Self.a, rows: [Self.root, Self.handOver(to: Self.b), Self.reply], age: 60)
        try log(Self.b, rows: [Self.otherRoot, Self.reply], age: 30)
        #expect(try resolve(Self.a) == "\(Self.a).jsonl")
    }

    @Test func aSubagentReplyAfterTheHandOverDoesNotCount() throws {
        try log(Self.a, rows: [Self.root, Self.handOver(to: Self.b), Self.sidechainReply], age: 60)
        try log(Self.b, rows: [Self.otherRoot, Self.reply], age: 30)
        #expect(try resolve(Self.a) == "\(Self.b).jsonl")
    }

    @Test func aHandOverCycleOrMissingTargetStops() throws {
        try log(Self.a, rows: [Self.root, Self.handOver(to: Self.b)], age: 60)
        try log(Self.b, rows: [Self.otherRoot, Self.handOver(to: Self.a)], age: 30)
        try log(
            Self.c, in: "-home-user-other", rows: [Self.root, Self.handOver(to: Self.b.replacing("b", with: "f"))],
            age: 5)
        #expect(try resolve(Self.a) == "\(Self.b).jsonl")
        #expect(try resolve(Self.c) == "\(Self.c).jsonl")
    }

    @Test func aNewerLongerCopyOfTheConversationWins() throws {
        try log(Self.a, rows: [Self.root, Self.reply], age: 60)
        try log(Self.b, rows: [Self.root, Self.reply, Self.reply], age: 30)
        try log(Self.c, rows: [Self.root, Self.reply, Self.reply, Self.reply], age: 10)
        #expect(try resolve(Self.a) == "\(Self.c).jsonl")
    }

    @Test func aCopyMustShareTheRootBeNewerNoShorterAndNotHandedOver() throws {
        try log(Self.a, rows: [Self.root, Self.reply, Self.reply], age: 60)
        try log(Self.b, rows: [Self.otherRoot, Self.reply, Self.reply, Self.reply], age: 30)
        try log(Self.c, rows: [Self.root], age: 10)
        #expect(try resolve(Self.a) == "\(Self.a).jsonl")

        try log(Self.c, rows: [Self.root, Self.reply, Self.reply, Self.handOver(to: Self.b)], age: 10)
        #expect(try resolve(Self.a) == "\(Self.a).jsonl")

        try log(Self.c, rows: [Self.root, Self.reply, Self.reply, Self.reply], age: 90)
        #expect(try resolve(Self.a) == "\(Self.a).jsonl")
    }
}
