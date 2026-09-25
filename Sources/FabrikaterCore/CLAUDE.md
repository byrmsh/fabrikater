# FabrikaterCore

Plain value types shared by every layer, plus the `Log` wrapper. Builds and tests on Linux.

- Foundation only. No SwiftUI, AppKit or `os` imports outside `#if canImport(os)`.
- Depends on nothing. Every other target may depend on it.
- Types here are `Sendable` value types that validate on construction. Anything that reaches a remote shell (`PaneID`, later session ids) rejects invalid input in `init?` and in `Decodable`.
- Decode Herdr's strings leniently: unknown agents become `.other`, unknown statuses `.unknown`. Never fail a whole snapshot over a new value.
- Tests: `Tests/FabrikaterCoreTests`, with swift-testing. Shared fixtures live in `Tests/Fixtures`.
- Before adding a type here, ask whether a single target uses it. If so, it belongs in that target.
