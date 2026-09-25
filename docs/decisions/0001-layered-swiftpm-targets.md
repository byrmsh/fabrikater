# 0001: Layered SwiftPM targets, most of them building on Linux

Status: accepted (foundation session, 2026-09-25)

## Context

The app is developed mostly by cloud agents on Linux, without macOS, Xcode or access to the host. The user builds on a Mac with only the Command Line Tools. Most of the app's risk is in logic (SSH plumbing, lenient decoding, log parsing, screen grammars, send safety), not in views.

## Decision

One SwiftPM package, split into targets by layer: `FabrikaterCore`, `HostKit`, `HerdrKit`, `TranscriptKit`, `PromptKit` and `AppModel` build and test on Linux; `AppUI` and the `fabrikater` executable are macOS-only and are gated with `#if os(macOS)` in `Package.swift`. The stores in `AppModel` are `@MainActor @Observable` and get their services through protocols, so UI behaviour is tested on Linux. A target is created only when its first real code lands. The planned targets live in [../structure.md](../structure.md), not as empty folders.

M0 created `FabrikaterCore`, `AppUI` and `fabrikater`. M0 has no store, so `AppModel` arrives with the sidebar in M1.

Every target uses Swift 6 language mode (complete strict concurrency), plus the `ExistentialAny` and `MemberImportVisibility` upcoming features: they cost nothing in a new code base and make dependencies explicit. `swift-tools-version` is 6.2, below the 6.4 everyone runs, so a slightly older toolchain can still read the manifest.

## Consequences

- `swift test` on Linux covers everything except views, so cloud agents can test real behaviour.
- The layering is enforced by the compiler: a lower target cannot import a higher one.
- Views cannot be compiled in cloud sessions. The macOS CI job ([0002](0002-ci-on-linux-and-macos-clt.md)) and the user's manual check cover them, which is why views hold no logic.
- `Log` wraps `os.Logger` behind `#if canImport(os)` so that Core stays Linux-clean.
