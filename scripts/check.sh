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

if [ "$(uname -s)" = "Darwin" ]; then
    developer_dir="${DEVELOPER_DIR:-$(xcode-select -p)}"
    if [[ "${developer_dir}" == *CommandLineTools* ]]; then
        # The CLT ship swift-testing outside the paths SwiftPM searches (docs/macos-tooling.md section 1).
        # Its macro plugin sits in host/plugins/testing, which swiftbuild does not load by itself; the framework
        # and its interop library need rpaths at run time. Verified on CLT 27.0 in CI (docs/decisions/0003).
        frameworks="${developer_dir}/Library/Developer/Frameworks"
        swift_flags+=(
            -Xswiftc -plugin-path -Xswiftc "${developer_dir}/usr/lib/swift/host/plugins/testing"
            -Xswiftc -F -Xswiftc "${frameworks}"
            -Xlinker -rpath -Xlinker "${frameworks}"
            -Xlinker -rpath -Xlinker "${developer_dir}/Library/Developer/usr/lib"
        )
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
swift test --disable-xctest "${swift_flags[@]}"

section "all checks passed"
