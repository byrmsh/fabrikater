#!/bin/bash
# Builds release, assembles build/fabrikater.app and ad-hoc signs it. Run it on macOS, then `open build/fabrikater.app`.
#   FABRIKATER_BUILD_SYSTEM=native   use SwiftPM's native build engine from the start
set -euo pipefail
cd "$(dirname "$0")/.."

if [ "$(uname -s)" != "Darwin" ]; then
    echo "bundle.sh builds the macOS app and needs macOS" >&2
    exit 1
fi

version="0.1.0"
build_number="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
app="build/fabrikater.app"

build=(swift build -c release --product fabrikater)
if [ -n "${FABRIKATER_BUILD_SYSTEM:-}" ]; then
    build+=(--build-system "${FABRIKATER_BUILD_SYSTEM}")
fi
if ! "${build[@]}"; then
    # docs/macos-tooling.md section 1: the swiftbuild engine has known failures under the Command Line Tools.
    echo "bundle.sh: the default build engine failed, retrying with --build-system native" >&2
    build=(swift build -c release --product fabrikater --build-system native)
    "${build[@]}"
fi
bin_dir="$("${build[@]}" --show-bin-path)"

rm -rf "${app}"
mkdir -p "${app}/Contents/MacOS" "${app}/Contents/Resources"
cp "${bin_dir}/fabrikater" "${app}/Contents/MacOS/fabrikater"
sed -e "s/__VERSION__/${version}/" -e "s/__BUILD__/${build_number}/" Bundle/Info.plist >"${app}/Contents/Info.plist"
plutil -lint "${app}/Contents/Info.plist"

# Resource bundles of dependencies must sit in Resources, or Bundle.module crashes at launch.
find "${bin_dir}" -maxdepth 1 -name '*.bundle' -exec cp -R {} "${app}/Contents/Resources/" \;

codesign --force --deep --sign - "${app}"
codesign --verify --deep --strict "${app}"
echo "bundle.sh: built ${app} (${version}, build ${build_number})"
