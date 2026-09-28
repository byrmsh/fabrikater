# 0012: SwiftTerm for the terminal view, fed one read at a time

Status: accepted (2026-09-28)

## Context

M4 adds the Terminal view ([../design.md](../design.md), "Terminal view"): a read-only rendering of a pane's recent output with its ANSI colours, for what the conversation cannot show. [../macos-tooling.md](../macos-tooling.md) section 3 chose SwiftTerm and pinned it to v1.20.0, because its main branch is taking breaking changes. It is the app's first third-party dependency.

Herdr has no stream of a pane's raw output that fabrikater uses, so the view shows snapshots: `herdr pane read <pane> --source recent --format ansi --lines 400` ([../architecture.md](../architecture.md), "Terminal read").

## Decision

- **SwiftTerm v1.20.0, exact, for `AppUI` only.** `Package.swift` adds it inside `#if os(macOS)`, so the Linux build never resolves it. Its only product used is the AppKit `TerminalView`, with no process behind it. SwiftTerm lists `Apple/Metal/Shaders.metal` as a resource; the Command Line Tools do not compile Metal, and SwiftTerm compiles the shader from its source at run time when no compiled library is present, so the resource bundle is copied as is by `scripts/bundle.sh`. The default (non-Metal) renderer is used.
- **Reads live in the lower targets.** `HostCommand.herdrPaneRecent` is the read, `HerdrKit`'s `TerminalReader` (implemented by `HerdrClient`) returns it, and `AppModel`'s `TerminalStore` polls it every 1.2 s while the terminal view is on screen, and not at all otherwise. The view reports appearing and disappearing with `setTerminalVisible`. Each window has its own `TerminalStore`, like its conversation ([0010](0010-conversation-store-per-window.md)).
- **Each read replaces the last.** `TerminalScreen.bytes` feeds a full reset (`ESC c`), line wrapping off, the cursor hidden, then the text; a line wider than the view is clipped rather than wrapped, so a TUI's layout stays intact. `TerminalFeed` holds a new screen while the user has scrolled up and feeds it once they are back at the bottom, so reading older output never jumps. Both are pure values tested on Linux.
- **Read-only.** The view's delegate drops every keystroke and mouse report. Typing stays in the composer and the key bar.
- **`WorkspaceLayout` starts small.** It holds only which panel the detail shows (Conversation or Terminal), switched by a segmented control in the toolbar and View ▸ Show Terminal (⌘T). The tree of splits, tabs and docks in `.claude/skills/macos-design/references/layout-model.md` waits for movable panels ("Later" in milestones.md).

## Consequences

- The app bundle carries SwiftTerm's resource bundle; its licence is in THIRD_PARTY_NOTICES.md.
- The terminal is as wide as the view, not the pane: a pane wider than the view is clipped at the right edge. Sizing the view to the pane's columns needs the pane's width, which the snapshot does not report.
- A visible terminal costs one ssh round trip per 1.2 s over the shared ControlMaster connection. A minimised window keeps polling until the view disappears.
- SwiftTerm's transitive dependencies (swift-argument-parser, swift-docc-plugin) float within their declared ranges, since `Package.resolved` is not committed.
- Removing it: delete `AppUI/Terminal/`, `TerminalStore.swift`, `TerminalScreen.swift`, the `TerminalReader` protocol and the command, and the package line.
