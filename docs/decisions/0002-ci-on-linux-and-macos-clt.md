# 0002: CI on Linux, and on macOS with the Command Line Tools

Status: accepted (foundation session, 2026-09-25)

## Context

The repository is private, so macOS runner minutes cost ten times Linux minutes. The user builds with Command Line Tools 27.0 (Swift 6.4), not Xcode, and CLT fails in ways Xcode does not (the SwiftUI `State` macro, swift-testing paths). On 2026-09-24, `actions/runner-images` listed the `xcode-27` label (arm64, macOS 27.0, image 20260912, preview) with Xcode 27.0 as the default and "Xcode Command Line Tools 27.0" installed. The `macos-26` images carry only Xcode 26.x.

## Decision

- `linux.yml`: every PR and every push to `main`, in the `swift:6.4.0-noble` container, runs `scripts/check.sh`. It has no path filter because it is cheap.
- `macos.yml`: on `xcode-27`, with `DEVELOPER_DIR=/Library/Developer/CommandLineTools`, so CI builds exactly like the user's Mac. It runs `scripts/check.sh` and `scripts/bundle.sh`, checks that `codesign -dv` reports `Signature=adhoc` with identifier `sh.bayram.fabrikater`, launches the app and checks that it is still running 5 s later, and uploads a screenshot (replaced by the end-to-end flows in [0008](0008-e2e-screenshot-flows.md)). It runs only when app-relevant paths change (sources, tests, manifest, bundle template, scripts, its own workflow), so docs-only and skills-only pushes skip it.
- `workflow_dispatch` with `toolchain: xcode` runs the same job under Xcode 27 on demand, to check that `scripts/check.sh` still works there without paying for it on every push.
- Both workflows cancel a stale run when a new push arrives and cache `.build`.

## Consequences

- CLT-only breakage shows up in CI, not on the user's Mac.
- `xcode-27` is a preview image. If it is renamed or retired, move to the newest image whose `runner-images` readme lists CLT 27 or later, and update this file.
- A docs-only PR shows no macOS check. That is fine as long as the check isn't marked required.
