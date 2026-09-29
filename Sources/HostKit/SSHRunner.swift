import FabrikaterCore
import Foundation

/// Runs commands on the host through `/usr/bin/ssh`, sharing one ControlMaster connection.
public struct SSHRunner: HostCommandRunner {
    /// A GUI app inherits no shell `PATH`, so ssh is started by absolute path.
    public static let sshPath = "/usr/bin/ssh"

    private let host: HostAlias
    private let log = Log(category: "HostKit")

    public init(host: HostAlias) {
        self.host = host
    }

    public func run(_ command: HostCommand, input: Data?) async throws(HostError) -> Data {
        let child = ChildProcess(executable: Self.sshPath, arguments: SSHArguments.arguments(for: command, host: host))
        let clock = ContinuousClock()
        let started = clock.now
        let output = try await child.run(input: input, timeout: command.timeout)
        log.debug(
            "ran \(command.fixtureNames[0]): status \(output.status), \(output.stdout.count) bytes in \(clock.now - started)"
        )
        guard output.status == 0 else {
            throw .exited(status: output.status, stderr: ChildProcess.text(output.stderr))
        }
        return output.stdout
    }

    public func lines(_ command: HostCommand, input: Data?) -> AsyncThrowingStream<String, any Error> {
        log.debug("streaming \(command.fixtureNames[0])")
        let child = ChildProcess(executable: Self.sshPath, arguments: SSHArguments.arguments(for: command, host: host))
        return child.lines(input: input)
    }

    /// Drops the shared connection: after the Mac sleeps it is usually dead, but ssh takes up to 45 s
    /// (`ServerAliveInterval` × `ServerAliveCountMax`) to notice, and every command riding on it hangs until then.
    public func closeSharedConnection() async {
        let child = ChildProcess(executable: Self.sshPath, arguments: SSHArguments.closeSharedConnection(host: host))
        do {
            _ = try await child.run(input: nil, timeout: .seconds(5))
            log.info("closed the shared connection")
        } catch {
            log.error("closing the shared connection failed: \(error)")
        }
    }
}
