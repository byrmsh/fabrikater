# Code structure

How the code is laid out, what may depend on what, and where each kind of change goes. [architecture.md](architecture.md) says what the app talks to; this file says where that code lives. When the structure doesn't fit a change, propose the new shape before writing code and record it in [decisions/](decisions/).

## Targets

One SwiftPM package. Each layer is its own target, so the compiler enforces the layering. A target is created only when its first real code lands. The table lists the planned ones so later milestones know where their code goes.

| Target | Builds on | Exists since | Holds | Depends on |
|---|---|---|---|---|
| `FabrikaterCore` | Linux, macOS | M0 | Plain value types shared by every layer (`PaneID`, `AgentKind`, `AgentStatus`) and the `Log` wrapper. Foundation only. | nothing |
| `HostKit` | Linux, macOS | M1 | `HostCommand` (every remote script, its timeout and replay fixture), `SSHArguments`, the `HostCommandRunner` protocol with `SSHRunner` (`/usr/bin/ssh` through `Process`) and `ReplayRunner` (fixture files), `LineBuffer`, and `HostError`. | Core |
| `HerdrKit` | Linux, macOS | M1 | `Herd` (the snapshot, decoded leniently), `HerdrClient` (snapshot and events channel), `HerdFeed` (coalesced refresh plus safety poll), `HerdrRequest` and `HerdrControl` (focus and sends over the API socket), `PaneReader` (the visible screen, for the send guard), `ScreenCheck` (what the host checks right before a keystroke), and `SendPolicy` with `PolicedControl`. Terminal-view reads come in M4. | Core, HostKit |
| `TranscriptKit` | Linux, macOS | M1 (minimal) | The transcript model, the Claude parser and `HostTranscriptService` (one read of the log's last 512 KB, then a live `tail -F` follow). Hand-over resolution runs on the host, in `HostKit`'s Claude log prefix; backfill comes in M2 ([parsing.md](parsing.md) sections 1 to 3). | Core, HostKit |
| `PromptKit` | Linux, macOS | M3 (send guard) | `Screen` (ANSI text to plain lines), `Dialog` (is a dialog showing?) and `InputBox` (Claude Code's input box and its draft) since M3; the screen grammars and the answer guard in M5 ([parsing.md](parsing.md) section 4). | Core |
| `AppModel` | Linux, macOS | M1 | `@MainActor @Observable` stores (`AppStore`: sidebar, selection, connection state; `ConversationStore`: one window's pane transcript, with `TranscriptCache`; `PaneWindowStore`: a pane window's own conversation, composer and panels; `MenuTarget`: routes menu commands to the front window; `ComposerStore`: per-pane drafts and sending; `FocusSync`: Herdr's focus following the selection), `SendGuard` (the screen check before typing), plus the platform-neutral UI values from `.claude/skills/macos-design`: `AppCommand`, `Keymap` and (from M4) `WorkspaceLayout`. Each store gets its services through protocols or streams, injected by its initializer. | Core, and HerdrKit, TranscriptKit and PromptKit through their protocols |
| `AppUI` | macOS | M0 | Thin SwiftUI views over `AppModel`, one folder per feature (`Sidebar/`, `Conversation/`, `Commands/`, `Composer/`, …), plus `ViewState`. | AppModel, and TranscriptKit for the transcript value types it renders |
| `fabrikater` | macOS | M0 | The executable: `FabrikaterApp` and the single composition root. It wires the real services, or the replay ones when launched with `FABRIKATER_FIXTURES=<dir>` (from M1, in debug and release builds), which also keep pane notes in their own defaults domain, `sh.bayram.fabrikater.fixtures`. The host alias comes from `FABRIKATER_HOST` (default `arch`) until the Settings scene exists. | everything |

```
FabrikaterCore ◄── HostKit ◄── HerdrKit ◄──┐
      ▲   ▲            ▲                   │
      │   └────── TranscriptKit ◄──────────┤
      └────────── PromptKit ◄──────────────┤
                                        AppModel ◄── AppUI ◄── fabrikater
```

`Package.swift` adds `AppUI` and `fabrikater` only under `#if os(macOS)`, so on Linux `swift build` and `swift test` cover every other target. Tests use swift-testing, with one test target per library target (`<Target>Tests`).

## Dependency rules

- Arrows point one way only. A lower target never imports a higher one, and nothing imports `fabrikater`.
- Only `AppUI` and `fabrikater` import SwiftUI or AppKit. Everything below builds on Linux, so it must import nothing that is macOS-only (use `#if canImport(os)` as `Log` does).
- Views contain layout only. A decision, a formatted string, or anything worth a test belongs in a store or a lower target, where it is tested on Linux.
- Everything above `AppUI` is written so that a port to another platform (Android is the likely one) rewrites only the views: user actions are `AppCommand` cases, shortcuts are `Keymap` entries, and panel placement is a `WorkspaceLayout` value, all in `AppModel`.
- Stores never create their own services. The composition root in `fabrikater` builds the service graph once and passes it into each store's initializer. There are no singletons outside it.
- A new third-party dependency lands in the milestone that first uses it, pinned: SwiftTerm in M4 ([macos-tooling.md](macos-tooling.md)). Only `AppUI` may depend on UI packages.

## Engineering rules

- Swift 6 language mode with complete strict concurrency, plus the `ExistentialAny` and `MemberImportVisibility` upcoming features. Zero warnings: `scripts/check.sh` builds with `-warnings-as-errors`.
- No Combine and no bare `DispatchQueue`: use Observation, `async`/`await`, actors and `AsyncSequence`. `scripts/check.sh` rejects both.
- Never await the host on the main actor while handling input. Change local state first (clear the composer, mark the draft as sending, update the selection), then let the host catch up in a task.
- Every host call has a timeout and throws a typed error. The UI shows the error; nothing hangs.
- When the host is unreachable, show the last known data and say that it is stale. Never clear it.
- Never write the SwiftUI state wrapper as `@State`: write `@ViewState`. Also avoid `#Preview`, `@Previewable`, `@Entry` and SwiftData. `scripts/check.sh` rejects them, because they break the Command Line Tools build (see [macos-tooling.md](macos-tooling.md) section 1).
- A `TODO` or `FIXME` names its milestone, like `TODO(M3)`. There is no commented-out code.
- Logging goes through `Log(category:)`, with one category per target (`Log(category: "HerdrKit")`). Messages are public in the unified log, so log ids, sizes and states, never user text or pane contents. Signpost intervals get added to `Log` the first time something is measured (planned for M2's transcript loading).

## Fixtures

Test fixtures live in `Tests/Fixtures/` and are shared by every test target. Load them by path relative to the test file (see `Tests/FabrikaterCoreTests/Fixture.swift`), not as resources.

- `*.synthetic.*` files are hand-written from the shapes documented in [architecture.md](architecture.md). They say what the docs claim, not what the host does.
- Other files are captured from the host with `scripts/capture-fixtures.sh`, which runs on the Mac, uses read-only commands only, and scrubs paths, titles, labels and session ids (`scripts/scrub-snapshot.jq`). Claude session logs (`claude-capture-N.jsonl`: the last lines of the two newest logs and of the newest one calling a task-tracking tool) are scrubbed down to their shape by `scripts/scrub-claude-log.jq`: every prompt, reply, command, result and path becomes a placeholder, keeping types, roles, tool names, statuses, tags and ids of the same shape, and `CaptureScrubTests` checks that the scrub keeps what the parsers read. `claude-tools.txt` counts the built-in tools the newest 50 logs call. It refuses to write if the host's home, the host user or the local user survives the scrub. Add every new capture there, with its own scrub, rather than copying files by hand.
- Scrubbed free text is an opaque placeholder. `terminal_title` and `terminal_title_stripped` are scrubbed independently (a pane's pair reads `Title 61` / `Title 25`), and labels become `Workspace N` / `Tab N`, so no spinner glyph, prefix or real label survives. Captures show shapes, ids, statuses and how records relate; test any logic that reads titles or labels (stripping, label fallback, `fabrikater-test` matching beyond the kept label) against a synthetic fixture.

## Recipes

M1 settled the host, Herdr and store recipes below; the parser recipe is still a plan until M2. If a milestone finds a recipe wrong, update it in the same PR.

### Add a host command

1. Add a case to `HostCommand` in `HostKit`, for example `.statSize(session: SessionID)`, with its `remoteScript`. Arguments must be validated types (`PaneID`, `SessionID`), never a bare `String` from the UI, and anything interpolated goes through `shellQuoted`. User text never becomes an argument: it goes on stdin, and the remote side reads it with `"$(cat)"`.
2. Give it a `timeout` (or mark it `isStreaming`). Runners map every failure onto `HostError`; a script can signal "not found" with `HostCommand.notFoundStatus`.
3. Give it `fixtureNames` and add the fixture to `Tests/Fixtures/` (extend `scripts/capture-fixtures.sh` if it reads the host), so `ReplayRunner`, tests and `FABRIKATER_FIXTURES` mode can run it.
4. Test on Linux the exact argument vector the builder produces, including a rejected identifier.
5. If the command changes Herdr, it is not a new `HostCommand`: add a `HerdrRequest` case instead, which travels on the existing `herdrRequests` command. Mark whether it `typesIntoPane`, so `PolicedControl` asks `SendPolicy` first.

### Add a Herdr event

1. Add the subscription type to `HerdrClient.subscriptions` in `HerdrKit` (valid names are in [architecture.md](architecture.md), "Events").
2. Treat the event as a poke: `HerdFeed` turns it into a coalesced snapshot re-read, and it carries no state into the model. Only add a payload decoder if a specific UI reaction needs one.
3. Add a synthetic event line to `Tests/Fixtures/events.synthetic.jsonl` if a test needs it.

### Add an agent parser

1. Add the resolution rules and a parser type in `TranscriptKit`, keyed by exact `AgentKind` (`omp` maps to the pi parser; see [parsing.md](parsing.md) 1.1).
2. Ported code keeps the Collie attribution header (`// Ported from AltanS/collie@b7ddc17 <path> (MIT)`) and THIRD_PARTY_NOTICES.md stays current.
3. Add trimmed and scrubbed host logs to `Tests/Fixtures/` plus Collie's own test cases, and test on Linux: parsing, tool-result folding, and a clipped first line and a partial last line.
4. Views need no change if the parser emits the normalized transcript model.

### Add a store plus a view

1. Write the store in `AppModel` as a `@MainActor @Observable final class`. Its initializer takes the protocols or streams it needs. Its input methods update state synchronously, then start any host work in a `Task`. User actions are `AppCommand` cases routed through `AppStore.perform(_:)`.
2. Test it on Linux with fake services: state after each input, what happens when a service errors, and stale data kept while offline.
3. Write the view in `AppUI/<Feature>/`. It reads the store and calls `perform(_:)`, and holds only view-local state (`@ViewState private var`). Design and review it with `.claude/skills/macos-design` and the vendored skills in `.claude/skills/`, where the repo's rules win.
4. Wire the store once in the composition root in `fabrikater` (`FabrikaterApp.init`), and add menu items to `AppUI/Commands/`.
5. Anything visual goes on the PR's "manual on the Mac" checklist.
