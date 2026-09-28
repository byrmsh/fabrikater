import FabrikaterCore
import Foundation
import Synchronization

/// Serves commands from files in a fixture directory (`HostCommand.fixtureNames`) and never touches the host.
///
/// Streams yield the fixture's lines and then stay open, like a quiet event channel, until cancelled. A followed log
/// also yields the lines later appended to its fixture file, as `tail -F` does. Text typed into a pane shows on the
/// prompt row (`❯`) of its screen fixture until Enter, as an agent's input box would show it, so the send guard's
/// check that the text arrived passes. Screen checks are not run.
public struct ReplayRunner: HostCommandRunner {
    private let directory: URL
    private let pollInterval: Duration
    private let typed = Typed()
    private let log = Log(category: "HostKit")

    /// - Parameter pollInterval: how often a followed fixture is checked for appended lines.
    public init(directory: URL, pollInterval: Duration = .milliseconds(250)) {
        self.directory = directory
        self.pollInterval = pollInterval
    }

    public func run(_ command: HostCommand, input: Data?) async throws(HostError) -> Data {
        let data = try fixture(for: command)
        switch command {
        case .logTail(_, let bytes):
            return data.suffix(bytes)
        case .herdrRequests:
            typed.record(input ?? Data())
        case .herdrPaneScreen(let pane):
            return typed.echo(into: data, pane: pane.rawValue)
        default:
            break
        }
        return data
    }

    public func lines(_ command: HostCommand, input: Data?) -> AsyncThrowingStream<String, any Error> {
        if case .logFollow(_, let bytes) = command {
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

/// What each pane was sent with `pane.send_text` since its last Enter.
private final class Typed: Sendable {
    private let text = Mutex<[String: String]>([:])

    /// Reads the requests script's stdin (`HostCommand.herdrRequests`), skipping screen checks.
    func record(_ input: Data) {
        var skip = 0
        for line in String(decoding: input, as: UTF8.self).split(separator: "\n") {
            if skip > 0 {
                skip -= 1
                continue
            }
            if line.hasPrefix("?") {
                skip = line.split(separator: " ").suffix(2).compactMap { Int($0) }.reduce(0, +)
                continue
            }
            guard let request = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                let params = request["params"] as? [String: Any], let pane = params["pane_id"] as? String
            else { continue }
            if let sent = params["text"] as? String {
                let plain = sent.replacing("\u{1B}[200~", with: "").replacing("\u{1B}[201~", with: "")
                text.withLock { $0[pane, default: ""] += plain }
            } else if (params["keys"] as? [String])?.contains("Enter") == true {
                text.withLock { $0[pane] = nil }
            }
        }
    }

    /// The screen with the pane's typed text on its last prompt row.
    func echo(into screen: Data, pane: String) -> Data {
        guard let typed = text.withLock({ $0[pane] }) else { return screen }
        // Bytes, not Characters: in Swift `\r\n` is one Character, which splitting on `"\n"` would not match.
        var lines = screen.split(separator: 0x0A, omittingEmptySubsequences: false).map { Data($0) }
        let prompt = Data("❯".utf8)
        guard let row = lines.lastIndex(where: { $0.firstRange(of: prompt) != nil }) else { return screen }
        let ending = lines[row].last == 0x0D ? "\r" : ""
        lines[row] = Data(("❯ " + typed.split(whereSeparator: \.isNewline).joined(separator: " ") + ending).utf8)
        return Data(lines.joined(separator: [0x0A]))
    }
}
