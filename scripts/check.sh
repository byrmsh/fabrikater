#!/bin/bash
# The one check every agent and CI runs: format lint, source lint, build (warnings are errors), tests.
# Works on Linux, and on macOS under Xcode or under the Command Line Tools (CLT).
#   FABRIKATER_BUILD_SYSTEM=native   use SwiftPM's native build engine (the fallback in docs/macos-tooling.md)
set -euo pipefail
cd "$(dirname "$0")/.."

section() { printf '\n==> %s\n' "$1"; }

swift_flags=(-Xswiftc -warnings-as-errors)
if [ -n "${FABRIKATER_BUILD_SYSTEM:-}" ]; then
    swift_flags+=(--build-system "${FABRIKATER_BUILD_SYSTEM}")
fi

test_flags=()
if [ "$(uname -s)" = "Darwin" ]; then
    developer_dir="${DEVELOPER_DIR:-$(xcode-select -p)}"
    if [[ "${developer_dir}" == *CommandLineTools* ]]; then
        # CLT ships swift-testing outside the default search paths (docs/macos-tooling.md section 1).
        # Confirmed on the CI runner's CLT 27.0; confirm on the Mac with scripts/check.sh.
        frameworks="${developer_dir}/Library/Developer/Frameworks"
        test_flags+=(-Xswiftc -F -Xswiftc "${frameworks}" -Xlinker -rpath -Xlinker "${frameworks}")
        interop="${developer_dir}/Library/Developer/usr/lib"
        if [ -d "${interop}" ]; then
            test_flags+=(-Xlinker -rpath -Xlinker "${interop}")
        fi
    fi
fi

section "format lint"
swift format lint --strict --recursive --parallel Package.swift Sources Tests

section "source lint"
# Each rule: a grep -E pattern, then why it is banned. See CLAUDE.md and docs/decisions/0003.
rules=(
    '@State([^A-Za-z0-9_]|$)' "the CLT's SDK resolves @State to an Xcode-only macro; write @ViewState"
    '#Preview' "preview macros need Xcode"
    '@Previewable' "preview macros need Xcode"
    '@Entry([^A-Za-z0-9_]|$)' "the @Entry macro needs Xcode; write the EnvironmentKey by hand"
    '^[[:space:]]*import[[:space:]]+SwiftData' "SwiftData macros need Xcode; store plain Codable values"
    '^[[:space:]]*import[[:space:]]+Combine' "use Observation and async sequences, not Combine"
    'DispatchQueue' "use Swift concurrency, not DispatchQueue"
)
lint_failed=0
for ((i = 0; i < ${#rules[@]}; i += 2)); do
    if hits=$(grep -rnE --include='*.swift' -- "${rules[i]}" Sources Tests); then
        printf '%s\n  -> %s\n' "${hits}" "${rules[i + 1]}"
        lint_failed=1
    fi
done
if hits=$(grep -rnE --include='*.swift' 'TODO|FIXME' Sources Tests | grep -vE '(TODO|FIXME)\(M[0-9]+\)'); then
    printf '%s\n  -> a TODO or FIXME names its milestone, like TODO(M3)\n' "${hits}"
    lint_failed=1
fi
if [ "${lint_failed}" -ne 0 ]; then
    exit 1
fi

section "build"
swift build --build-tests "${swift_flags[@]}"

section "test"
swift test --disable-xctest "${swift_flags[@]}" ${test_flags[@]+"${test_flags[@]}"}

section "all checks passed"
