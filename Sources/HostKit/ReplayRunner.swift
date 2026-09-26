import FabrikaterCore
import Foundation

/// Serves commands from files in a fixture directory (`HostCommand.fixtureNames`) and never touches the host.
///
/// Streams yield the fixture's lines and then stay open, like a quiet event channel, until cancelled.
public struct ReplayRunner: HostCommandRunner {
    private let directory: URL
    private let log = Log(category: "HostKit")

    public init(directory: URL) {
        self.directory = directory
    }

    public func run(_ command: HostCommand, input: Data?) async throws(HostError) -> Data {
        let data = try fixture(for: command)
        if case .claudeLogTail(_, let bytes) = command {
            return data.suffix(bytes)
        }
        return data
    }

    public func lines(_ command: HostCommand, input: Data?) -> AsyncThrowingStream<String, any Error> {
        AsyncThrowingStream { continuation in
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

    private func fixture(for command: HostCommand) throws(HostError) -> Data {
        for name in command.fixtureNames {
            if let data = try? Data(contentsOf: directory.appending(component: name)) {
                log.debug("replay \(name) (\(data.count) bytes)")
                return data
            }
        }
        throw .noFixture(command.fixtureNames.joined(separator: " or "))
    }
}
