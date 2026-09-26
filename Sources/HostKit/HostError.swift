/// Why a host command failed. Every runner throws only this.
public enum HostError: Error, Equatable, Sendable, CustomStringConvertible {
    /// `/usr/bin/ssh` (or the fixture) could not be started.
    case launchFailed(String)
    /// The command did not finish within its timeout and was stopped.
    case timedOut(seconds: Int)
    /// The remote command, or ssh itself (status 255), exited with a non-zero status.
    case exited(status: Int32, stderr: String)
    /// A replay runner has no fixture for the command.
    case noFixture(String)

    public var description: String {
        switch self {
        case .launchFailed(let reason): "Could not start ssh: \(reason)"
        case .timedOut(let seconds): "The host did not answer within \(seconds) s"
        case .exited(255, let stderr): "ssh failed: \(Self.firstLine(stderr, or: "connection error"))"
        case .exited(let status, let stderr):
            "Host command failed (\(status)): \(Self.firstLine(stderr, or: "no output"))"
        case .noFixture(let name): "No fixture named \(name)"
        }
    }

    private static func firstLine(_ text: String, or fallback: String) -> String {
        let line = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        return line.isEmpty ? fallback : line
    }
}
