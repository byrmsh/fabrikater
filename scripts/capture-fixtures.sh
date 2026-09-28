#!/bin/bash
# Run on the Mac. Captures host data into Tests/Fixtures with read-only commands only: the Herdr snapshot, scrubbed by
# scrub-snapshot.jq, and the last lines of a few Claude session logs, scrubbed by scrub-claude-log.jq down to their
# shape (no prompt, reply, command or file text survives). Review the diff before committing.
#   FABRIKATER_HOST=arch            the ssh alias to read from
#   FABRIKATER_CAPTURE_LINES=300    how many of each log's last lines to keep
set -euo pipefail
cd "$(dirname "$0")/.."

host="${FABRIKATER_HOST:-arch}"
ssh_cmd=(/usr/bin/ssh -o BatchMode=yes "${host}")
out="Tests/Fixtures/snapshot.json"
raw="$(mktemp)"
trap 'rm -f "${raw}" Tests/Fixtures/*.tmp' EXIT

"${ssh_cmd[@]}" herdr api snapshot >"${raw}"
remote_home="$("${ssh_cmd[@]}" 'printf %s "$HOME"')"
remote_user="$("${ssh_cmd[@]}" 'id -un')"

jq -f scripts/scrub-snapshot.jq "${raw}" >"${out}.tmp"

# Fails, and names the file, when any of the host's or this Mac's home or user names survived scrubbing.
check_scrubbed() {
    local leaked=0 needle
    for needle in "${remote_home}" "${remote_user}" "$(id -un)" "${HOME}"; do
        if [ -n "${needle}" ] && grep -qiF -- "${needle}" "$1"; then
            echo "capture-fixtures.sh: '${needle}' survived scrubbing in $1; not writing it" >&2
            grep -noiF -- "${needle}" "$1" | head -5 >&2
            leaked=1
        fi
    done
    return "${leaked}"
}

check_scrubbed "${out}.tmp"
mv "${out}.tmp" "${out}"
echo "capture-fixtures.sh: wrote ${out} ($(jq '.result.snapshot.panes | length' "${out}") panes)"

# Claude logs: the two newest, plus the newest of the last 50 that calls a task-tracking tool (TodoWrite, or the
# Task* tools newer Claude Code versions use), so the plan panel (B10) can be checked against real rows.
lines="${FABRIKATER_CAPTURE_LINES:-300}"
logs="$("${ssh_cmd[@]}" 'recent=$(ls -1t ~/.claude/projects/*/*.jsonl 2>/dev/null | head -n 50); '\
'printf "%s\n" "$recent" | head -n 2; '\
'[ -z "$recent" ] || printf "%s\n" "$recent" | tr "\n" "\0" '\
'| xargs -0 grep -l -E "\"name\":\"(TodoWrite|Task[A-Z][A-Za-z]*)\"" 2>/dev/null | head -n 1' | awk 'NF && !seen[$0]++')"
n=0
while IFS= read -r log; do
    n=$((n + 1))
    capture="Tests/Fixtures/claude-capture-${n}.jsonl"
    quoted="'$(printf %s "${log}" | sed "s/'/'\\\\''/g")'"
    "${ssh_cmd[@]}" "tail -n ${lines} ${quoted}" | jq -R -c 'fromjson? // empty' \
        | jq -s -c -f scripts/scrub-claude-log.jq >"${capture}.tmp"
    check_scrubbed "${capture}.tmp"
    mv "${capture}.tmp" "${capture}"
    echo "capture-fixtures.sh: wrote ${capture} ($(wc -l <"${capture}" | tr -d ' ') rows)"
done <<<"${logs}"

# Which built-in tools the newest logs call, by count: shows whether TodoWrite or newer task tools are in use.
tools="Tests/Fixtures/claude-tools.txt"
"${ssh_cmd[@]}" 'ls -1t ~/.claude/projects/*/*.jsonl 2>/dev/null | head -n 50 | tr "\n" "\0" '\
'| xargs -0 tail -q -c 2000000 | grep -oE "\"name\":\"[A-Za-z]+\",\"input\"" '\
'| cut -d "\"" -f 4 | sort | uniq -c | sort -rn' >"${tools}.tmp"
check_scrubbed "${tools}.tmp"
mv "${tools}.tmp" "${tools}"
echo "capture-fixtures.sh: wrote ${tools} ($(wc -l <"${tools}" | tr -d ' ') tools)"
