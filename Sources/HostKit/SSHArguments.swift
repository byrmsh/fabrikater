/// The argument vector for `/usr/bin/ssh` (docs/architecture.md, "SSH setup").
public enum SSHArguments {
    /// Options every call passes: never prompt, share one master connection, detect a dead link, compress.
    public static let options = [
        "-o", "BatchMode=yes",
        "-o", "ControlMaster=auto",
        "-o", "ControlPath=~/.ssh/cm-fabrikater-%C",
        "-o", "ControlPersist=10m",
        "-o", "ServerAliveInterval=15",
        "-o", "ServerAliveCountMax=3",
        "-o", "Compression=yes",
    ]

    public static func arguments(for command: HostCommand, host: HostAlias) -> [String] {
        options + (command.isStreaming ? ["-T"] : []) + [host.rawValue, "--", command.remoteScript]
    }

    /// Ends the shared master connection and every command riding on it, so the next command connects afresh.
    public static func closeSharedConnection(host: HostAlias) -> [String] {
        options + ["-O", "exit", host.rawValue]
    }
}
