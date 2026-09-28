import FabrikaterCore
import Foundation

/// Serves commands from files in a fixture directory (`HostCommand.fixtureNames`) and never touches the host.
///
/// Streams yield the fixture's lines and then stay open, like a quiet event channel, until cancelled. A followed log
/// also yields the lines later appended to its fixture file, as `tail -F` does.
public struct ReplayRunner: HostCommandRunner {
    private let directory: URL
    private let pollInterval: Duration
    private let log = Log(category: "HostKit")

    /// - Parameter pollInterval: how often a followed fixture is checked for appended lines.
    public init(directory: URL, pollInterval: Duration = .milliseconds(250)) {
        self.directory = directory
        self.pollInterval = pollInterval
    }

    public func run(_ command: HostCommand, input: Data?) async throws(HostError) -> Data {
        let data = try fixture(for: command)
        if case .claudeLogTail(_, let bytes) = command {
            return data.suffix(bytes)
        }
        return data
    }

    public func lines(_ command: HostCommand, input: Data?) -> AsyncThrowingStream<String, any Error> {
        if case .claudeLogFollow(_, let bytes) = command {
            return follow(command, bytes: bytes)
        }
        return AsyncThrowingStream { continuation in
            do {
                var buffer = LineBuffer()
                for line in buffer.append(try fixture(for: command)) {
                    continuation.yield(line)
                }
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }

    /// The fixture's last `bytes` bytes, then whatever is appended to the file, polled. A file that shrank was
    /// replaced, so it is read again from the start.
    private func follow(_ command: HostCommand, bytes: Int) -> AsyncThrowingStream<String, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let url = try fixtureURL(for: command)
                    var buffer = LineBuffer()
                    var offset = max((try Data(contentsOf: url)).count - max(bytes, 1), 0)
                    while !Task.isCancelled {
                        let data = (try? Data(contentsOf: url)) ?? Data()
                        if data.count < offset { offset = 0 }
                        for line in buffer.append(data.suffix(from: offset)) {
                            continuation.yield(line)
                        }
                        offset = data.count
                        try await Task.sleep(for: pollInterval)
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func fixture(for command: HostCommand) throws(HostError) -> Data {
        let url = try fixtureURL(for: command)
        guard let data = try? Data(contentsOf: url) else { throw .noFixture(url.lastPathComponent) }
        log.debug("replay \(url.lastPathComponent) (\(data.count) bytes)")
        return data
    }

    private func fixtureURL(for command: HostCommand) throws(HostError) -> URL {
        let urls = command.fixtureNames.map { directory.appending(component: $0) }
        guard let url = urls.first(where: { FileManager.default.fileExists(atPath: $0.path(percentEncoded: false)) })
        else {
            throw .noFixture(command.fixtureNames.joined(separator: " or "))
        }
        return url
    }
}
