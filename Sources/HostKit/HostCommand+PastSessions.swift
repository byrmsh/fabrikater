// Listing a Claude session's siblings, the other conversations started in the same working directory, for the Past
// Sessions sheet. One ssh round trip prints everything the sheet shows.

import FabrikaterCore

extension HostCommand {
    /// How many logs the listing prints, newest first.
    static let pastSessionLimit = 60

    /// Prints the live log's file name on the first line, then one line per log in its folder, newest first:
    /// modification time (epoch seconds), size in bytes and file name, then up to three candidate first-prompt rows,
    /// each cut to 8 KB, all separated by tabs. JSON lines hold no raw tabs, so a tab always separates fields.
    ///
    /// A candidate is a main-thread user row that is not meta, not a tool result, and whose text does not open with a
    /// tag (system reminders, slash commands and their output); only the first megabyte of each log is searched.
    static func pastSessions(besides session: SessionID) -> String {
        claudeLog(session)
            + #"printf '%s\n' "${f##*/}"; "#
            + #"ls -1t "${f%/*}"/*.jsonl 2>/dev/null | head -n \#(pastSessionLimit) | while IFS= read -r g; do "#
            + #"printf '%s\t%s\t%s' "$(stat -c %Y "$g" 2>/dev/null || stat -f %m "$g")" "$(wc -c < "$g" | tr -d ' ')" "${g##*/}"; "#
            + #"head -c 1048576 "$g" | LC_ALL=C awk '/"type":"user"/ && !/"isMeta":true/ && !/"isSidechain":true/ "#
            + #"&& !/"tool_result"/ && !/"(content|text)":"</ { printf "\t%s", substr($0, 1, 8192); if (++n == 3) exit }'; "#
            + "echo; done"
    }
}
