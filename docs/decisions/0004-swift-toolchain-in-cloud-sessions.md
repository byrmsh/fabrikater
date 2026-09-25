# 0004: Install Swift in cloud sessions with a SessionStart hook

Status: accepted (foundation session, 2026-09-25)

## Context

Claude Code cloud sessions run in fresh Ubuntu 24.04 x86_64 containers with no Swift toolchain. The user's Mac runs Swift 6.4, and download.swift.org publishes 6.4.0 for Ubuntu 24.04.

## Decision

`.claude/hooks/session-start.sh`, registered in `.claude/settings.json`, runs synchronously at session start, and only when `CLAUDE_CODE_REMOTE=true` on Linux. If `~/.cache/fabrikater/swift-6.4.0/usr/bin/swift` is missing, it downloads `swift-6.4.0-RELEASE-ubuntu24.04.tar.gz` (1.1 GB), checks the pinned SHA-256, unpacks it there, and adds `usr/bin` to `PATH` through `$CLAUDE_ENV_FILE`. The tarball's PGP signature was checked against swift.org's release keys when the hash was pinned. The container already has the toolchain's system libraries. Measured in the foundation session, the download took about 6 s and the unpack about 30 s. If the hook's container state is cached, later sessions skip both.

## Consequences

- Every cloud session starts with `swift`, `swift format` and swift-testing available, and `scripts/check.sh` just works.
- To move to a new Swift release, change `version` and `sha256` in the hook (verify the new signature first) and the container tag in `linux.yml`, together.
- Local sessions on the Mac are unaffected: the hook exits immediately there.
