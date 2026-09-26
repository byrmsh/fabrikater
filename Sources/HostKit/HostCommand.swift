import FabrikaterCore

/// Every command fabrikater runs on the host. The only way to build a remote command line.
public enum HostCommand: Hashable, Sendable {
    /// `herdr api snapshot`: the whole herd as JSON (docs/architecture.md, "Control: snapshot").
    case herdrSnapshot
    /// A connection to Herdr's API socket, for `events.subscribe` written on stdin (docs/architecture.md, "Events").
    case herdrEvents
    /// Herdr API requests, one JSON line each on stdin, each sent on its own socket connection in order with a short
    /// settle between them; prints one reply line per request (docs/architecture.md, "Control: requests").
    case herdrRequests
    /// The last `bytes` bytes of the Claude session log for `session`, found by scanning the project directories
    /// (docs/parsing.md 1.2). Exits with `notFoundStatus` when no log exists.
    case claudeLogTail(session: SessionID, bytes: Int)

    /// The exit status a command's script uses for "the file does not exist".
    public static let notFoundStatus: Int32 = 44

    /// The shell command line the remote side runs. Interpolated values are validated types, single-quoted.
    public var remoteScript: String {
        switch self {
        case .herdrSnapshot:
            "herdr api snapshot"
        case .herdrEvents:
            #"socat - UNIX-CONNECT:"$HOME/.config/herdr/herdr.sock""#
        case .herdrRequests:
            // The socket answers one request per connection; `-t 5` waits for the reply after stdin closes. A refusal
            // stops the loop, so Enter is never sent after its text was refused.
            #"n=0; while IFS= read -r l; do [ $n -eq 0 ] || sleep 0.3; n=1; "#
                + #"r=$(printf '%s\n' "$l" | socat -t 5 - UNIX-CONNECT:"$HOME/.config/herdr/herdr.sock") || exit 1; "#
                + #"printf '%s\n' "$r"; case "$r" in *'"error":{'*) exit 0;; esac; done"#
        case .claudeLogTail(let session, let bytes):
            // TODO(M2): follow hand-overs and the conversation root to the live file (docs/parsing.md 1.3).
            "f=$(ls -1t ~/.claude/projects/*/\(shellQuoted(session.rawValue + ".jsonl")) 2>/dev/null | head -n 1); "
                + "[ -n \"$f\" ] || exit \(Self.notFoundStatus); tail -c \(max(bytes, 1)) \"$f\""
        }
    }

    /// Long-lived commands stream until cancelled and have no timeout.
    public var isStreaming: Bool {
        switch self {
        case .herdrEvents: true
        case .herdrSnapshot, .herdrRequests, .claudeLogTail: false
        }
    }

    /// How long a one-off command may take before it is stopped.
    public var timeout: Duration {
        switch self {
        case .herdrSnapshot: .seconds(10)
        case .herdrEvents: .seconds(0)
        case .herdrRequests: .seconds(15)
        case .claudeLogTail: .seconds(20)
        }
    }

    /// The fixture file `ReplayRunner` serves for this command, most specific first.
    public var fixtureNames: [String] {
        switch self {
        case .herdrSnapshot: ["snapshot.json", "snapshot.synthetic.json"]
        case .herdrEvents: ["events.synthetic.jsonl"]
        case .herdrRequests: ["requests.synthetic.jsonl"]
        case .claudeLogTail(let session, _): ["claude-\(session.rawValue).jsonl", "claude.synthetic.jsonl"]
        }
    }
}

/// Wraps `value` in single quotes for a POSIX shell, so the remote shell passes it through as one word.
func shellQuoted(_ value: String) -> String {
    "'" + value.replacing("'", with: #"'\''"#) + "'"
}
