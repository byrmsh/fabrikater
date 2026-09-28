import FabrikaterCore
import Foundation
import HostKit
import Testing

@testable import TranscriptKit

struct LiveFollowTests {
    /// Serves `reads` in order (the last repeats) and one prepared follow stream per follow, in order.
    private final class FollowRunner: HostCommandRunner, @unchecked Sendable {
        let reads: [Data]
        let follows: [AsyncThrowingStream<String, any Error>]
        private(set) var readCount = 0
        private var followCount = 0

        init(reads: [Data], follows: [AsyncThrowingStream<String, any Error>]) {
            self.reads = reads
            self.follows = follows
        }

        func run(_ command: HostCommand, input: Data?) async throws(HostError) -> Data {
            defer { readCount += 1 }
            return reads[min(readCount, reads.count - 1)]
        }

        func lines(_ command: HostCommand, input: Data?) -> AsyncThrowingStream<String, any Error> {
            defer { followCount += 1 }
            return followCount < follows.count ? follows[followCount] : AsyncThrowingStream { _ in }
        }
    }

    private struct MissingLogRunner: HostCommandRunner {
        func run(_ command: HostCommand, input: Data?) async throws(HostError) -> Data {
            throw .exited(status: HostCommand.notFoundStatus, stderr: "")
        }

        func lines(_ command: HostCommand, input: Data?) -> AsyncThrowingStream<String, any Error> {
            AsyncThrowingStream { _ in }
        }
    }

    private let claudeLog = SessionLog(format: .claude, session: SessionID("00000000-0000-4000-8000-000000000001")!)

    private func lines(named name: String) throws -> [String] {
        String(decoding: try Fixture.data(named: name), as: UTF8.self).split(separator: "\n").map(String.init)
    }

    private func first(_ count: Int, of stream: AsyncThrowingStream<Transcript, any Error>) async throws -> [Transcript]
    {
        var transcripts: [Transcript] = []
        for try await transcript in stream {
            transcripts.append(transcript)
            if transcripts.count == count { break }
        }
        return transcripts
    }

    @Test func aLineWrittenAfterTheReadAppearsAndTheOverlapDoesNot() async throws {
        let log = try Fixture.data(named: "claude.synthetic.jsonl")
        let appended = try lines(named: "claude-follow.synthetic.jsonl")
        let old = try lines(named: "claude.synthetic.jsonl")
        let (follow, feed) = AsyncThrowingStream<String, any Error>.makeStream()
        feed.yield("ped\"}")  // the overlap starts mid-line
        for line in old.suffix(3) { feed.yield(line) }
        for line in appended { feed.yield(line) }
        let service = HostTranscriptService(runner: FollowRunner(reads: [log], follows: [follow]))

        let transcripts = try await first(
            3, of: service.followTranscript(of: claudeLog, bytes: TranscriptWindow.full))
        #expect(transcripts[0].entries.count == 9)
        #expect(transcripts[1].entries.last?.id == "u20")
        #expect(transcripts[2].entries.count == 11)
        #expect(transcripts[2].entries.last?.id == "a20")
    }

    @Test func aDroppedFollowReadsAgainAndFollowsOn() async throws {
        let log = try Fixture.data(named: "claude.synthetic.jsonl")
        let grown = log + (try Fixture.data(named: "claude-follow.synthetic.jsonl"))
        let (dropped, feed) = AsyncThrowingStream<String, any Error>.makeStream()
        feed.finish(throwing: HostError.exited(status: 255, stderr: "connection lost"))
        let runner = FollowRunner(reads: [log, grown], follows: [dropped])
        let service = HostTranscriptService(runner: runner, reconnectDelays: [.zero])

        let transcripts = try await first(
            2, of: service.followTranscript(of: claudeLog, bytes: TranscriptWindow.full))
        #expect(transcripts[0].entries.count == 9)
        #expect(transcripts[1].entries.count == 11)
        #expect(runner.readCount == 2)
    }

    @Test func aMissingLogEndsTheFollow() async {
        let service = HostTranscriptService(runner: MissingLogRunner())
        await #expect(throws: TranscriptError.noLog) {
            _ = try await first(1, of: service.followTranscript(of: claudeLog, bytes: TranscriptWindow.full))
        }
    }

    @Test func theWindowHoldsBackAHalfWrittenLastLine() {
        var window = LogWindow(.claude, read: Data("{\"a\":1}\n{\"b\":".utf8), limit: 1024)
        #expect(window.data == Data("{\"a\":1}\n".utf8))
        let added = window.append("{\"b\":2}")
        #expect(added)
        #expect(window.data == Data("{\"a\":1}\n{\"b\":2}\n".utf8))
    }

    @Test func theWindowAddsEachLineOnce() {
        var window = LogWindow(.claude, read: Data("{\"a\":1}\n".utf8), limit: 1024)
        let added = ["{\"a\":1}", "", "{\"b\":2}", "{\"b\":2}"].map { window.append($0) }
        #expect(added == [false, false, true, false])
        #expect(window.data == Data("{\"a\":1}\n{\"b\":2}\n".utf8))
    }

    @Test func aWindowGrownPastTwiceItsLimitDropsItsOldestBytesAndSaysSo() {
        var window = LogWindow(.claude, read: Data("{\"a\":1}\n".utf8), limit: 16)
        #expect(!window.isClipped)
        _ = window.append("{\"b\":2222222222}")
        _ = window.append("{\"c\":3333333333}")
        #expect(window.data.count == 16)
        #expect(window.isClipped)
        #expect(window.transcript.isClipped)
    }

    @Test func aServiceWithoutLiveFollowReadsOnceAndEnds() async throws {
        struct OneRead: TranscriptService {
            func transcript(of log: SessionLog, bytes: Int) async throws -> Transcript {
                Transcript(isClipped: bytes == TranscriptWindow.full)
            }
        }
        var transcripts: [Transcript] = []
        for try await transcript in OneRead().followTranscript(of: claudeLog, bytes: TranscriptWindow.full) {
            transcripts.append(transcript)
        }
        #expect(transcripts == [Transcript(isClipped: true)])
    }
}
