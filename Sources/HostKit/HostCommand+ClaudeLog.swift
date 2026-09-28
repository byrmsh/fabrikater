// Finding a Claude session's live log on the host (docs/parsing.md 1.2 and 1.3), as the shell prefix every Claude log
// command starts with. It runs on the host so a read or follow stays one ssh round trip.

import FabrikaterCore

extension HostCommand {
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
}
