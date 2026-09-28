// Listing the other conversations of a pane's working directory, for the Past Sessions sheet. One ssh round trip
// prints everything the sheet shows. Each agent keeps its sessions its own way, so each has its own listing, but all
// print the same lines: the live session's name first, then one line per session, newest first, with its modification
// time (epoch seconds), size in bytes, name and up to three candidate first-prompt rows, all separated by tabs. JSON
// lines hold no raw tabs, so a tab always separates fields. `PastSession.parse(listing:format:)` reads them.

import FabrikaterCore

extension HostCommand {
    /// How many sessions a listing prints, newest first.
    static let pastSessionLimit = 60
    /// How many of Codex's newest rollouts, from every project, are read for their working directory.
    static let codexScanLimit = 500

    static func pastSessions(besides log: SessionLog) -> String {
        switch log.format {
        case .claude: claudeSessions(log.session)
        case .codex: codexSessions(log.session)
        case .pi: piSessions(log.session)
        case .opencode: openCodeSessions(log.session)
        }
    }

    /// The logs in the live Claude log's folder, which Claude names after the working directory. A candidate is a
    /// main-thread user row that is not meta, not a tool result, and whose text does not open with a tag (system
    /// reminders, slash commands and their output).
    static func claudeSessions(_ session: SessionID) -> String {
        claudeLog(session)
            + folderListing(
                rows: #"/"type":"user"/ && !/"isMeta":true/ && !/"isSidechain":true/ && !/"tool_result"/ "#
                    + #"&& !/"(content|text)":"</"#)
    }

    /// The logs in the live pi or omp log's folder, which both agents name after the working directory. A candidate
    /// is a user message row.
    static func piSessions(_ session: SessionID) -> String {
        piLog(session) + folderListing(rows: #"/"type":"message"/ && /"role":"user"/"#)
    }

    /// Codex keeps every project's rollouts in date folders, so the newest `codexScanLimit` are read for the working
    /// directory their first row (`session_meta`) names, and those matching the live rollout's are listed. A candidate
    /// is the prompt as typed (`user_message`), or a user message that does not open with a tag (the injected
    /// environment context).
    static func codexSessions(_ session: SessionID) -> String {
        let cwd = #"head -c 65536 "$1" | head -n 1 | grep -o '"cwd":"[^"]*"' | head -n 1"#
        return codexLog(session)
            + "cwd() { \(cwd); }; "
            + #"c=$(cwd "$f"); printf '%s\n' "${f##*/}"; n=0; "#
            + #"ls -1t "${CODEX_HOME:-$HOME/.codex}"/sessions/*/*/*/rollout-*.jsonl 2>/dev/null "#
            + #"| head -n \#(codexScanLimit) | while IFS= read -r g; do "#
            + #"{ [ -n "$c" ] && [ "$(cwd "$g")" = "$c" ]; } || [ "$g" = "$f" ] || continue; "#
            + describeLog(
                rows: #"/"type":"event_msg"/ && /"type":"user_message"/ "#
                    + #"|| /"type":"response_item"/ && /"role":"user"/ && !/"text":"</"#)
            + #"n=$((n + 1)); [ $n -lt \#(pastSessionLimit) ] || break; done"#
    }

    /// OpenCode's sessions (V1 store) whose directory is the live session's, subagent sessions left out. The size is
    /// that of the session's message and part data, the modification time its `time_updated`, and the one candidate
    /// row a JSON object holding the title OpenCode gave the session. Only the `session`, `message` and `part` tables
    /// are read. The id is a validated `ses_` id of letters and digits, so it is safe inside the quoted SQL.
    static func openCodeSessions(_ session: SessionID) -> String {
        let id = "'\(session.rawValue)'"
        func size(_ table: String) -> String {
            "coalesce((select sum(length(data)) from \(table) where session_id = s.id), 0)"
        }
        let listing =
            "select (s.time_updated / 1000) || char(9) || (\(size("message")) + \(size("part"))) || char(9) || s.id "
            + "|| char(9) || json_object('title', s.title) from session s "
            + "where s.directory = (select directory from session where id = \(id)) and s.parent_id is null "
            + "order by s.time_updated desc limit \(pastSessionLimit)"
        return openCodeDatabase
            + "[ -n \"$(q \"select 1 from session where id = \(id)\")\" ] || exit \(notFoundStatus); "
            + "printf '%s\\n' \(id); q \"\(listing)\""
    }

    /// Prints the live log `f`'s file name, then a line per log in its folder, newest first.
    private static func folderListing(rows: String) -> String {
        #"printf '%s\n' "${f##*/}"; "#
            + #"ls -1t "${f%/*}"/*.jsonl 2>/dev/null | head -n \#(pastSessionLimit) | while IFS= read -r g; do "#
            + describeLog(rows: rows) + "done"
    }

    /// Prints the log `g`'s line: its modification time, size and file name, then up to three rows of its first
    /// megabyte that the awk pattern `rows` matches, each cut to 8 KB.
    private static func describeLog(rows: String) -> String {
        #"printf '%s\t%s\t%s' "$(stat -c %Y "$g" 2>/dev/null || stat -f %m "$g")" "$(wc -c < "$g" | tr -d ' ')" "${g##*/}"; "#
            + #"head -c 1048576 "$g" | LC_ALL=C awk '\#(rows) { printf "\t%s", substr($0, 1, 8192); if (++n == 3) exit }'; "#
            + "echo; "
    }
}
