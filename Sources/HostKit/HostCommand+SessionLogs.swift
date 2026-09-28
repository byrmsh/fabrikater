// Finding a session's live log on the host (docs/parsing.md 1.2 and 1.3), as the shell prefix every log command starts
// with. It runs on the host so a read or follow stays one ssh round trip.

import FabrikaterCore

extension HostCommand {
    /// Prints the log's last `bytes` bytes.
    static func tail(of log: SessionLog, bytes: Int) -> String {
        switch log.format {
        case .opencode: openCodeRows(log.session) + "rows -1 | tail -c \(bytes)"
        default: locate(log) + "tail -c \(bytes) \"$f\""
        }
    }

    /// Prints the log's last `bytes` bytes, then what is added to it until cancelled. An OpenCode session is polled
    /// every 2 s and each message changed since the last poll is printed again whole, starting 10 s before the
    /// follow, so nothing written between the read and the follow is lost; the parser keeps a message's last line.
    static func follow(_ log: SessionLog, bytes: Int) -> String {
        switch log.format {
        case .opencode:
            // The blank first line stands in for the clipped line a `tail -F` starts with.
            openCodeRows(log.session) + #"l=$(($(latest) - 10000)); echo; "#
                + #"while :; do n=$(latest) || exit 1; [ "$n" = "$l" ] || { rows "$l" || exit 1; l=$n; }; sleep 2; done"#
        default: locate(log) + "exec tail -c \(bytes) -F \"$f\""
        }
    }

    /// Sets `f` to the log's file, or exits with `notFoundStatus`.
    static func locate(_ log: SessionLog) -> String {
        switch log.format {
        case .claude: claudeLog(log.session)
        case .codex: codexLog(log.session)
        case .pi: piLog(log.session)
        case .opencode: "exit \(notFoundStatus); "
        }
    }

    /// The newest `rollout-<ts>-<uuid>.jsonl` under Codex's date directories (`YYYY/MM/DD`). Codex reports a resumed
    /// session's new id, so there are no hand-overs to follow.
    static func codexLog(_ session: SessionID) -> String {
        newest(#""${CODEX_HOME:-$HOME/.codex}"/sessions/*/*/*/rollout-*-"# + shellQuoted(session.rawValue + ".jsonl"))
    }

    /// The newest `<ts>_<uuid>.jsonl` in a working-directory folder of omp's or pi's sessions; both agents write the
    /// pi format, and their folder names are scanned rather than derived from the working directory.
    static func piLog(_ session: SessionID) -> String {
        let name = "*_" + shellQuoted(session.rawValue + ".jsonl")
        return newest(#""$HOME"/.omp/agent/sessions/*/"# + name + #" "$HOME"/.pi/agent/sessions/*/"# + name)
    }

    /// Sets `f` to the most recently written file among the `globs`, or exits with `notFoundStatus`.
    private static func newest(_ globs: String) -> String {
        "f=$(ls -1t \(globs) 2>/dev/null | head -n 1); [ -n \"$f\" ] || exit \(notFoundStatus); "
    }

    /// Sets `f` to the session's live log, or exits with `notFoundStatus`: the log found by scanning the project
    /// directories, then followed through hand-overs, then to the newest copy of the same conversation.
    static func claudeLog(_ session: SessionID) -> String {
        "f=$(ls -1t ~/.claude/projects/*/\(shellQuoted(session.rawValue + ".jsonl")) 2>/dev/null | head -n 1); "
            + "[ -n \"$f\" ] || exit \(notFoundStatus); "
            + followHandOvers + followConversationRoot
    }

    /// Prints the session id a log's tail hands over to, or nothing when the log is live. Read newest-first, the first
    /// `continued-in` row wins unless a main-thread assistant row comes after it; subagent (sidechain) rows don't count.
    private static let handOverTarget =
        #"awk 'match($0, /"continuedInSessionId":"[0-9A-Fa-f-]+"/) { n = substr($0, RSTART + 24, RLENGTH - 25); next } "#
        + #"/"type":"assistant"/ && !/"isSidechain":true/ { n = "" } END { if (length(n) == 36) print n }'"#

    /// Step 1 of parsing.md 1.3: up to 8 `continued-in` hops, looking beside the log first, then in every project;
    /// stops at a cycle or a missing target.
    private static let followHandOvers =
        #"s=" $f "; i=0; while [ $i -lt 8 ]; do "#
        + #"n=$(tail -c 65536 "$f" | \#(handOverTarget)); [ -n "$n" ] || break; "#
        + #"g="${f%/*}/$n.jsonl"; [ -f "$g" ] || g=$(ls -1t ~/.claude/projects/*/"$n.jsonl" 2>/dev/null | head -n 1); "#
        + #"[ -n "$g" ] || break; case "$s" in *" $g "*) break;; esac; s="$s$g "; f=$g; i=$((i + 1)); done; "#

    /// Step 2 of parsing.md 1.3: a sibling log that starts with the same root row (every copy of a conversation keeps
    /// it), was written later, is at least as long, and has not itself handed over. The newest one wins.
    private static let followConversationRoot =
        #"r=$(head -c 65536 "$f" | grep -m 1 -o '"uuid":"[^"]*"'); if [ -n "$r" ]; then b=$f; "#
        + #"for g in "${f%/*}"/*.jsonl; do [ "$g" -nt "$b" ] && [ $(wc -c < "$g") -ge $(wc -c < "$f") ] || continue; "#
        + #"[ "$(head -c 65536 "$g" | grep -m 1 -o '"uuid":"[^"]*"')" = "$r" ] || continue; "#
        + #"[ -z "$(tail -c 65536 "$g" | \#(handOverTarget))" ] || continue; b=$g; done; f=$b; fi; "#

    /// Sets `d` to OpenCode's database and defines `q SQL`, which runs a query on it read-only, or exits with
    /// `notFoundStatus` when there is no database.
    static let openCodeDatabase =
        #"d="${XDG_DATA_HOME:-$HOME/.local/share}/opencode/opencode.db"; "#
        + "[ -f \"$d\" ] || exit \(notFoundStatus); "
        + #"q() { sqlite3 -readonly -noheader "$d" "$1"; }; "#

    /// Defines `rows SINCE`, printing one JSON line per message of an OpenCode session updated after SINCE (ms), and
    /// `latest`, the session's newest update, reading OpenCode's database read-only (docs/parsing.md 2.4). It exits
    /// with `notFoundStatus` when neither store holds the session. The store with the newer rows wins, a tie going to
    /// V2. Only the session, message and part tables are read: the same file holds OAuth tokens. The id is a
    /// validated `ses_` id of letters and digits, so it is safe inside the quoted SQL.
    static func openCodeRows(_ session: SessionID) -> String {
        let id = "'\(session.rawValue)'"
        let v1Latest =
            "select coalesce(max(m), -1) from (select max(time_updated) m from message where session_id = \(id) "
            + "union all select max(time_updated) from part where session_id = \(id))"
        let v2Latest = "select coalesce(max(time_updated), -1) from session_message where session_id = \(id)"
        func json(_ column: String) -> String { "json(case when json_valid(\(column)) then \(column) else 'null' end)" }
        let v1Rows =
            "select json_object('id', m.id, 'ts', m.time_created, 'data', \(json("m.data")), 'parts', "
            + "json((select json_group_array(json_object('id', p.id, 'data', \(json("p.data")))) "
            + "from (select id, data from part where message_id = m.id order by id) p))) from message m "
            + "where m.session_id = \(id) and (coalesce(m.time_updated, 0) > $1 or exists (select 1 from part "
            + "where message_id = m.id and coalesce(time_updated, 0) > $1)) order by m.time_created, m.id"
        let v2Rows =
            "select json_object('id', id, 'ts', time_created, 'type', type, 'data', \(json("data"))) "
            + "from session_message where session_id = \(id) and coalesce(time_updated, 0) > $1 order by seq"
        return openCodeDatabase
            + #"t=$(q "select group_concat(' ' || name || ' ', '') from sqlite_master where type = 'table'") || exit 1; "#
            + #"m1=-1; m2=-1; case $t in *" message "*" part "*|*" part "*" message "*) "#
            + "m1=$(q \"\(v1Latest)\") || exit 1;; esac; "
            + "case $t in *\" session_message \"*) m2=$(q \"\(v2Latest)\") || exit 1;; esac; "
            + #"if [ "$m2" -ge 0 ] && [ "$m2" -ge "$m1" ]; then "#
            + "latest() { q \"\(v2Latest)\"; }; rows() { q \"\(v2Rows)\"; }; "
            + #"elif [ "$m1" -ge 0 ]; then "#
            + "latest() { q \"\(v1Latest)\"; }; rows() { q \"\(v1Rows)\"; }; "
            + "else exit \(notFoundStatus); fi; "
    }
}
