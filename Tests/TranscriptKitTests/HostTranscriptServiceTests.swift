import FabrikaterCore
import Foundation
import HostKit
import Testing

@testable import TranscriptKit

struct HostTranscriptServiceTests {
    private struct MissingLogRunner: HostCommandRunner {
        func run(_ command: HostCommand, input: Data?) async throws(HostError) -> Data {
            throw .exited(status: HostCommand.notFoundStatus, stderr: "")
        }

        func lines(_ command: HostCommand, input: Data?) -> AsyncThrowingStream<String, any Error> {
            AsyncThrowingStream { $0.finish() }
        }
    }

    private struct FixedLogRunner: HostCommandRunner {
        let data: Data

        func run(_ command: HostCommand, input: Data?) async throws(HostError) -> Data { data }

        func lines(_ command: HostCommand, input: Data?) -> AsyncThrowingStream<String, any Error> {
            AsyncThrowingStream { $0.finish() }
        }
    }

    private let session = SessionID("00000000-0000-4000-8000-000000000001")!

    @Test func loadsTheLogThroughTheRunner() async throws {
        let service = HostTranscriptService(runner: ReplayRunner(directory: Fixture.directory))
        let transcript = try await service.claudeTranscript(session: session, bytes: TranscriptWindow.full)
        #expect(transcript.entries.count == 9)
        #expect(!transcript.isClipped)
        #expect(transcript.todos.isEmpty)
    }

    @Test func attachesTheLatestPlan() async throws {
        let log = try Fixture.data(named: "claude-todos.synthetic.jsonl")
        let transcript = try await HostTranscriptService(runner: FixedLogRunner(data: log))
            .claudeTranscript(session: session, bytes: TranscriptWindow.full)
        #expect(transcript.todos.count == 4)
    }

    @Test func attachesTheChangedFiles() async throws {
        let log = try Fixture.data(named: "claude-changes.synthetic.jsonl")
        let transcript = try await HostTranscriptService(runner: FixedLogRunner(data: log))
            .claudeTranscript(session: session, bytes: TranscriptWindow.full)
        #expect(transcript.changes.map(\.name) == ["Uploader.swift", "RetryTests.swift"])
    }

    @Test func marksATranscriptLongerThanTheWindowAsClipped() async throws {
        let service = HostTranscriptService(runner: ReplayRunner(directory: Fixture.directory))
        let transcript = try await service.claudeTranscript(session: session, bytes: 1000)
        #expect(transcript.isClipped)
        #expect(transcript.entries.last?.id == "a7")
    }

    @Test func reportsAMissingLog() async {
        await #expect(throws: TranscriptError.noLog) {
            try await HostTranscriptService(runner: MissingLogRunner()).claudeTranscript(
                session: session, bytes: TranscriptWindow.full)
        }
    }
}
