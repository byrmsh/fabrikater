#!/bin/bash
# Installs the Swift toolchain in Claude Code cloud sessions (Linux). See docs/decisions/0004.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ] || [ "$(uname -s)" != "Linux" ]; then
    exit 0
fi

version="6.4.0"
# SHA-256 of the tarball below; its PGP signature was checked against swift.org/keys/all-keys.asc when pinned.
sha256="69f7b2b4dbce6090b6c92194b71149a057e16269093b5a9dded38afc4a05094e"
name="swift-${version}-RELEASE-ubuntu24.04"
url="https://download.swift.org/swift-${version}-release/ubuntu2404/swift-${version}-RELEASE/${name}.tar.gz"
cache="${HOME}/.cache/fabrikater"
prefix="${cache}/swift-${version}"

if [ ! -x "${prefix}/usr/bin/swift" ]; then
    mkdir -p "${cache}"
    tarball="${cache}/${name}.tar.gz"
    if ! echo "${sha256}  ${tarball}" | sha256sum --check --status 2>/dev/null; then
        curl --fail --silent --show-error --location --retry 4 --output "${tarball}" "${url}"
        echo "${sha256}  ${tarball}" | sha256sum --check --status
    fi
    rm -rf "${prefix}.partial"
    mkdir -p "${prefix}.partial"
    tar -xzf "${tarball}" -C "${prefix}.partial" --strip-components=1
    mv "${prefix}.partial" "${prefix}"
    rm -f "${tarball}"
fi

if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    echo "export PATH=\"${prefix}/usr/bin:\${PATH}\"" >>"${CLAUDE_ENV_FILE}"
fi
"${prefix}/usr/bin/swift" --version >&2
