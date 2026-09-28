# 0014: A native helper reads the accessibility tree for the e2e flows

Status: accepted (faster macOS CI session, 2026-09-28). Supersedes the "checks read the tree through System Events" part of [0008](0008-e2e-screenshot-flows.md).

## Context

The macOS job took 26 to 31 minutes, 24 of them in the end-to-end flows. Every text check asked System Events for the window's `entire contents` and then for each element's title, value, description and help tag. Each of those is its own Apple Event, so one check cost several seconds on a full window, and a flow with three checks took over 20 seconds. The checks poll, so every step paid for at least one full walk.

## Decision

- **`scripts/e2e/ax.swift` walks the tree in one process** with the Accessibility API (`AXUIElementCopyMultipleAttributeValues` per element). It reads text, dumps elements, presses a control, focuses a field, expands a disclosure triangle and reads the focused value, which is every step that walked the tree. `scripts/e2e.sh` compiles it with `swiftc` to `build/e2e-ax` before the flows and stops at once if the runner denies it Accessibility access.
- **Keys, menus, window counts, bounds and dark mode stay on System Events.** Each is one Apple Event, so they cost nothing to keep, and keystrokes through System Events are what the flows were written against.
- **It is a script, not a package target.** It imports ApplicationServices, runs only on macOS, and belongs to the test harness, not the app, so it stays out of `Package.swift` and the Linux build.
- The helper keeps System Events' semantics: depth-first tree order (which `e2e_expect_order` relies on), numbers as text, empty strings skipped. The flows did not change.

Rejected: fewer or merged flows (coverage stays), a longer timeout (hides the cost), shorter fixed sleeps alone (they add up to a few minutes at most, against about 20 in walks).

## Consequences

- The flows' steps and files are unchanged; only `lib.sh` and `e2e.sh` know about the helper.
- The helper is compiled on every e2e run, a few seconds.
- A step that reads or presses elements needs the helper; a new kind of tree query is a new command in `ax.swift`.
