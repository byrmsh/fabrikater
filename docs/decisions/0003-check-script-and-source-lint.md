# 0003: One check script with a format lint and a source lint

Status: accepted (foundation session, 2026-09-25)

## Context

Agents, CI and the user need one command that says "this is mergeable". Some rules can't be caught by any compiler in the loop: Linux never compiles SwiftUI, and Xcode accepts `@State`, `#Preview` and `@Entry`, which then break the Command Line Tools build.

## Decision

`scripts/check.sh` runs, in order:

1. `swift format lint --strict` with the repo's `.swift-format` (4-space indent, 120 columns, the default rules otherwise). swift-format ships with the toolchain, so it adds no dependency.
2. A grep-based source lint over `Sources` and `Tests` that fails on `@State` (but not `@StateObject`), `#Preview`, `@Previewable`, `@Entry`, `import SwiftData`, `import Combine`, `DispatchQueue`, and a `TODO`/`FIXME` without a milestone reference such as `TODO(M3)`.
3. `swift build --build-tests -Xswiftc -warnings-as-errors`.
4. `swift test --disable-xctest -Xswiftc -warnings-as-errors`.

On macOS under the Command Line Tools it adds the flags that make swift-testing work there (see the script's comments for what CI confirmed). `FABRIKATER_BUILD_SYSTEM=native` switches SwiftPM to its native engine, the documented fallback when swiftbuild misbehaves.

## Consequences

- The lint is textual, so a comment that spells out a banned token fails too. Write "the State property wrapper" in prose.
- Warnings as errors lives in the script, not in `Package.swift`, so local iteration isn't blocked and dependencies' warnings never break the build.
