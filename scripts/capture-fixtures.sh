#!/bin/bash
# Run on the Mac. Captures host data into Tests/Fixtures with read-only commands only, scrubbed of personal
# paths and names by scrub-snapshot.jq. Review the diff before committing.
#   FABRIKATER_HOST=archz   the ssh alias to read from
set -euo pipefail
cd "$(dirname "$0")/.."

host="${FABRIKATER_HOST:-archz}"
ssh_cmd=(/usr/bin/ssh -o BatchMode=yes "${host}")
out="Tests/Fixtures/snapshot.json"
raw="$(mktemp)"
trap 'rm -f "${raw}" "${out}.tmp"' EXIT

"${ssh_cmd[@]}" herdr api snapshot >"${raw}"
remote_home="$("${ssh_cmd[@]}" 'printf %s "$HOME"')"
remote_user="$("${ssh_cmd[@]}" 'id -un')"

jq -f scripts/scrub-snapshot.jq "${raw}" >"${out}.tmp"

leaked=0
for needle in "${remote_home}" "${remote_user}" "$(id -un)" "${HOME}"; do
    if [ -n "${needle}" ] && grep -qiF -- "${needle}" "${out}.tmp"; then
        echo "capture-fixtures.sh: '${needle}' survived scrubbing; not writing ${out}" >&2
        grep -noiF -- "${needle}" "${out}.tmp" | head -5 >&2
        leaked=1
    fi
done
if [ "${leaked}" -ne 0 ]; then
    exit 1
fi

mv "${out}.tmp" "${out}"
echo "capture-fixtures.sh: wrote ${out} ($(jq '.result.snapshot.panes | length' "${out}") panes)"
