import FabrikaterCore
import Foundation
import Testing

@testable import HostKit

/// Runs the OpenCode read against a database in a fake home, as the host would. Needs the sqlite3 command, as the
/// host has it.
@Suite(.enabled(if: FileManager.default.isExecutableFile(atPath: "/usr/bin/sqlite3")))
struct OpenCodeRowsTests {
    private let home: URL
    private let database: URL
    private static let id = "ses_0123456789abcdef"

    init() throws {
        home = FileManager.default.temporaryDirectory.appending(component: "fabrikater-\(UUID().uuidString)")
        database = home.appending(components: ".local", "share", "opencode", "opencode.db")
        try FileManager.default.createDirectory(
            at: database.deletingLastPathComponent(), withIntermediateDirectories: true)
    }

    private func sql(_ statements: String) throws {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/sqlite3")
        process.arguments = [database.path, statements]
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
    }

    private func v1(updated: Int) throws {
        try sql(
            """
            create table if not exists message(id text, session_id text, time_created int, time_updated int, data text);
            create table if not exists part(id text, message_id text, session_id text, time_updated int, data text);
            create table if not exists account(id text, token text);
            insert into account values ('a', 'SECRET');
            insert into message values ('msg_1', '\(Self.id)', 1000, 1000, '{"role":"user"}');
            insert into part values ('prt_1', 'msg_1', '\(Self.id)', 1000, '{"type":"text","text":"a\\nb"}');
            insert into message values ('msg_2', '\(Self.id)', 2000, 2000, '{"role":"assistant"}');
            insert into part values ('prt_3', 'msg_2', '\(Self.id)', \(updated), 'not json');
            insert into part values ('prt_2', 'msg_2', '\(Self.id)', 2000, '{"type":"text","text":"ok"}');
            """)
    }

    private func v2(updated: Int) throws {
        try sql(
            """
            create table session_message(id text, session_id text, type text, seq int, time_created int, time_updated int,
              data text);
            insert into session_message values ('m2', '\(Self.id)', 'assistant', 2, 20, \(updated), '{"content":[]}');
            insert into session_message values ('m1', '\(Self.id)', 'user', 1, 10, 10, '{"text":"hi"}');
            """)
    }

    /// The script's output, or nil when it exits as not found.
    private func run(_ tail: String) throws -> [String]? {
        try runScript(HostCommand.openCodeRows(try #require(SessionID(Self.id))) + tail)
    }

    private func runScript(_ script: String) throws -> [String]? {
        let process = Process()
        process.executableURL = URL(filePath: "/bin/sh")
        process.arguments = ["-c", script]
        process.environment = ["HOME": home.path, "PATH": "/usr/bin:/bin"]
        let output = Pipe()
        process.standardOutput = output
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        if process.terminationStatus == HostCommand.notFoundStatus { return nil }
        #expect(process.terminationStatus == 0)
        return String(decoding: data, as: UTF8.self).split(separator: "\n").map(String.init)
    }

    @Test func noDatabaseOrNoSessionIsNotFound() throws {
        #expect(try run("rows -1") == nil)
        try sql("create table message(id text, session_id text, time_created int, time_updated int, data text);")
        #expect(try run("rows -1") == nil)
    }

    @Test func printsOneLinePerV1MessageWithItsPartsInOrder() throws {
        try v1(updated: 3000)
        #expect(
            try run("rows -1") == [
                #"{"id":"msg_1","ts":1000,"data":{"role":"user"},"parts":[{"id":"prt_1","data":{"type":"text","text":"a\nb"}}]}"#,
                #"{"id":"msg_2","ts":2000,"data":{"role":"assistant"},"parts":[{"id":"prt_2","data":{"type":"text","text":"ok"}},{"id":"prt_3","data":null}]}"#,
            ])
        #expect(try run("latest") == ["3000"])
        let changed = try #require(try run("rows 2500"))
        #expect(changed.count == 1)
        #expect(changed.first?.hasPrefix(#"{"id":"msg_2""#) == true)
        #expect(try run("rows -1")?.joined().contains("SECRET") == false)
    }

    @Test func theStoreWithTheNewerRowsWins() throws {
        try v1(updated: 3000)
        try v2(updated: 20)
        #expect(try run("rows -1")?.first?.hasPrefix(#"{"id":"msg_1""#) == true)
        try sql("update session_message set time_updated = 3000 where id = 'm2';")
        #expect(
            try run("rows -1") == [
                #"{"id":"m1","ts":10,"type":"user","data":{"text":"hi"}}"#,
                #"{"id":"m2","ts":20,"type":"assistant","data":{"content":[]}}"#,
            ])
    }

    @Test func theTailIsTheLastBytes() throws {
        try v1(updated: 3000)
        let log = SessionLog(format: .opencode, session: try #require(SessionID(Self.id)))
        let script = HostCommand.logTail(log, bytes: 20).remoteScript
        #expect(script.hasSuffix("rows -1 | tail -c 20"))
        #expect(HostCommand.logFollow(log, bytes: 20).remoteScript.hasSuffix("sleep 2; done"))
    }

    @Test func listsTheSessionsOfTheLiveOnesDirectoryNewestFirst() throws {
        let listing = HostCommand.openCodeSessions(try #require(SessionID(Self.id)))
        #expect(try runScript(listing) == nil)
        try v1(updated: 3000)
        try sql(
            """
            create table session(id text, parent_id text, directory text, title text, time_updated int);
            insert into session values ('\(Self.id)', null, '/home/user/app', 'Rename the flag', 3000000);
            insert into session values ('ses_older0001', null, '/home/user/app', 'Tab\tin title', 2000000);
            insert into session values ('ses_child0001', '\(Self.id)', '/home/user/app', 'Subagent', 4000000);
            insert into session values ('ses_other0001', null, '/home/user/other', 'Elsewhere', 5000000);
            """)
        let lines = try runScript(listing)
        #expect(
            lines == [
                Self.id,
                "3000\t99\t\(Self.id)\t{\"title\":\"Rename the flag\"}",
                "2000\t0\tses_older0001\t{\"title\":\"Tab\\tin title\"}",
            ])
        #expect(try runScript(HostCommand.openCodeSessions(try #require(SessionID("ses_missing0001")))) == nil)
    }
}
