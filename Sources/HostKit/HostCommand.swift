import FabrikaterCore

/// Every command fabrikater runs on the host. The only way to build a remote command line.
public enum HostCommand: Hashable, Sendable {
    /// `herdr api snapshot`: the whole herd as JSON (docs/architecture.md, "Control: snapshot").
    case herdrSnapshot
    /// A connection to Herdr's API socket, for `events.subscribe` written on stdin (docs/architecture.md, "Events").
    case herdrEvents
    /// Herdr API requests, one JSON line each on stdin, each sent on its own socket connection in order with a short
    /// settle between them; prints one reply line per request (docs/architecture.md, "Control: requests").
    ///
    /// A request may follow a screen check: a line `?<pane> <window> <p> <r>`, then `p` phrases and `r` rows. The
    /// script reads the pane's visible screen, strips styling, spaces, tabs, carriage returns and no-break spaces, and
    /// drops blank rows. It sends the request only if none of the last three rows contains a phrase (case aside) and
    /// the `r` rows show one after another among the last `window` rows. Otherwise it prints an error reply with the
    /// code `screen_changed` and stops.
    case herdrRequests
    /// The last `bytes` bytes of the agent's session log, found by scanning the agent's session directories
    /// (docs/parsing.md 1.2, `HostCommand+SessionLogs.swift`). Exits with `notFoundStatus` when no log exists.
    case logTail(SessionLog, bytes: Int)
    /// The last `bytes` bytes of the same log, then every byte appended to it until cancelled (`tail -F`,
    /// docs/architecture.md, "Transcript tail"). Exits with `notFoundStatus` when no log exists.
    case logFollow(SessionLog, bytes: Int)
    /// The pane's current screen as ANSI text, for checking what typed text would land in (docs/parsing.md 4.1).
    /// `visible` never scrolls the operator's terminal, unlike a long `recent` read.
    case herdrPaneScreen(PaneID)
    /// The pane's last `lines` lines of screen and scrollback as ANSI text, for the terminal view (docs/architecture.md,
    /// "Terminal read").
    case herdrPaneRecent(PaneID, lines: Int)

    // The socket answers one request per connection; `-t 5` waits for the reply after stdin closes. A refusal stops
    // the loop, so Enter is never sent after its text was refused. The settle comes before a request's screen check,
    // not between the check and the request. Phrases and rows travel in the environment, never in an argument.
    static let requestsScript = #"""
        n=0; c=0
        while IFS= read -r l; do
          [ $c -eq 1 ] || [ $n -eq 0 ] || sleep 0.3; n=1; c=0
          case "$l" in '?'*)
            set -f; set -- ${l#?}; set +f
            p=$1; w=$2; h=; e=; i=0
            while [ $i -lt "$3" ]; do IFS= read -r x; h="$h$x
        "; i=$((i+1)); done
            i=0; while [ $i -lt "$4" ]; do IFS= read -r x; e="$e$x
        "; i=$((i+1)); done
            s=$(\#(Self.paneScreen(#""$p""#))) && printf '%s\n' "$s" | H="$h" E="$e" W="$w" LC_ALL=C awk '
              BEGIN { nh = split(ENVIRON["H"], h, "\n") - 1; ne = split(ENVIRON["E"], e, "\n") - 1; w = ENVIRON["W"] + 0 }
              { gsub(/\033\[[0-9;?]*[ -\/]*[@-~]|\033[@-Z\\_-]/, ""); gsub(/[ \t\r]|\302\240/, "")
                if ($0 != "") s[++c] = $0 }
              END {
                for (i = c - 2; i <= c; i++) if (i > 0) { t = tolower(s[i]); for (j = 1; j <= nh; j++) if (index(t, h[j])) exit 1 }
                if (ne <= 0) exit 0
                for (a = (c - w + 1 > 1 ? c - w + 1 : 1); a + ne - 1 <= c; a++) {
                  for (j = 1; j <= ne && (s[a + j - 1] "") == (e[j] ""); j++) {}
                  if (j > ne) exit 0
                }
                exit 1
              }' || { printf '%s\n' '{"error":{"code":"screen_changed","message":"screen check failed"}}'; exit 0; }
            c=1; continue;;
          esac
          r=$(printf '%s\n' "$l" | socat -t 5 - UNIX-CONNECT:"$HOME/.config/herdr/herdr.sock") || exit 1
          printf '%s\n' "$r"; case "$r" in *'"error":{'*) exit 0;; esac
        done
        """#

    /// `herdr pane read` of the visible screen, for a pane given as an already quoted shell word.
    static func paneScreen(_ quotedPane: String) -> String {
        "herdr pane read \(quotedPane) --source visible --format ansi"
    }

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
            Self.requestsScript
        case .logTail(let log, let bytes):
            Self.locate(log) + "tail -c \(max(bytes, 1)) \"$f\""
        case .logFollow(let log, let bytes):
            Self.locate(log) + "exec tail -c \(max(bytes, 1)) -F \"$f\""
        case .herdrPaneScreen(let pane):
            Self.paneScreen(shellQuoted(pane.rawValue))
        case .herdrPaneRecent(let pane, let lines):
            "herdr pane read \(shellQuoted(pane.rawValue)) --source recent --format ansi --lines \(min(max(lines, 1), 1000))"
        }
    }

    /// Long-lived commands stream until cancelled and have no timeout.
    public var isStreaming: Bool {
        switch self {
        case .herdrEvents, .logFollow: true
        case .herdrSnapshot, .herdrRequests, .logTail, .herdrPaneScreen, .herdrPaneRecent: false
        }
    }

    /// How long a one-off command may take before it is stopped.
    public var timeout: Duration {
        switch self {
        case .herdrSnapshot: .seconds(10)
        case .herdrEvents, .logFollow: .seconds(0)
        case .herdrRequests: .seconds(15)
        case .logTail: .seconds(20)
        case .herdrPaneScreen, .herdrPaneRecent: .seconds(5)
        }
    }

    /// The fixture file `ReplayRunner` serves for this command, most specific first.
    public var fixtureNames: [String] {
        switch self {
        case .herdrSnapshot: ["snapshot.json", "snapshot.synthetic.json"]
        case .herdrEvents: ["events.synthetic.jsonl"]
        case .herdrRequests: ["requests.synthetic.jsonl"]
        case .logTail(let log, _), .logFollow(let log, _):
            ["\(log.format.rawValue)-\(log.session.rawValue).jsonl", "\(log.format.rawValue).synthetic.jsonl"]
        case .herdrPaneScreen(let pane):
            ["screen-\(pane.fileName).txt", "screen-\(pane.fileName).synthetic.txt", "screen.synthetic.txt"]
        case .herdrPaneRecent(let pane, _):
            ["terminal-\(pane.fileName).txt", "terminal-\(pane.fileName).synthetic.txt"]
                + HostCommand.herdrPaneScreen(pane).fixtureNames
        }
    }
}

extension PaneID {
    /// The id with `:` replaced, for fixture file names: `w1:p1` is `w1-p1`.
    var fileName: String { rawValue.replacing(":", with: "-") }
}

/// Wraps `value` in single quotes for a POSIX shell, so the remote shell passes it through as one word.
func shellQuoted(_ value: String) -> String {
    "'" + value.replacing("'", with: #"'\''"#) + "'"
}
