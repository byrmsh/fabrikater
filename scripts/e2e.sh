#!/bin/bash
# Runs the end-to-end flows against build/fabrikater.app over fixtures (never the host) and saves screenshots.
#   scripts/e2e.sh                 every flow in scripts/e2e/flows
#   scripts/e2e.sh conversation    only the named flows
# Needs macOS, a logged-in desktop, and the app from scripts/bundle.sh. Screenshots land in build/e2e/.
# How to add a flow: docs/e2e.md.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ "$(uname -s)" != "Darwin" ]; then
    echo "e2e.sh drives the macOS app and needs macOS" >&2
    exit 1
fi

source scripts/e2e/lib.sh

if [ ! -x "${E2E_BINARY}" ]; then
    echo "e2e.sh: ${E2E_BINARY} is missing; run scripts/bundle.sh first" >&2
    exit 1
fi

rm -rf "${E2E_OUT}"
mkdir -p "${E2E_OUT}"

swiftc -swift-version 6 scripts/e2e/ax.swift -o "${E2E_AX}"
"${E2E_AX}" check

if [ "$#" -gt 0 ]; then
    flows=("$@")
else
    flows=()
    for file in scripts/e2e/flows/*.sh; do
        flows+=("$(basename "${file}" .sh)")
    done
fi

failed=()
for flow in "${flows[@]}"; do
    printf '\n==> e2e: %s\n' "${flow}"
    # Each flow runs in its own shell, so a failed step stops only that flow. The shell must not sit in an `if`,
    # which would switch off `set -e` inside it.
    set +e
    (
        set -euo pipefail
        E2E_FLOW="${flow}"
        trap 'status=$?; e2e_finish "${flow}" "${status}"; exit "${status}"' EXIT
        source "scripts/e2e/flows/${flow}.sh"
    )
    status=$?
    set -e
    if [ "${status}" -eq 0 ]; then
        echo "passed: ${flow}"
    else
        echo "FAILED: ${flow}" >&2
        failed+=("${flow}")
    fi
done

printf '\n==> screenshots in %s\n' "${E2E_OUT}"
ls -1 "${E2E_OUT}"
if [ "${#failed[@]}" -gt 0 ]; then
    echo "e2e: failed flows: ${failed[*]}" >&2
    exit 1
fi
echo "e2e: all flows passed"
