# Milestones

Each milestone ends with a check a person can perform and see pass. Do them in order; each builds on the last. Commit at least once per milestone.

Each check has two parts. **CI-verifiable** is what `scripts/check.sh` and the Linux and macOS workflows prove on every PR, so a cloud agent can drive it green alone. **Manual on the Mac** needs the host or the user's eyes; the agent lists it in the PR, with exact commands, for the user to run. Where code lives is in [structure.md](structure.md).

## M0: Toolchain and empty app

A SwiftPM package with one executable target and a `scripts/bundle.sh` that builds (`swift build -c release`, falling back to `--build-system native` if the default engine fails), assembles `build/fabrikater.app` with an Info.plist (`CFBundleIdentifier` `sh.bayram.fabrikater`, `LSMinimumSystemVersion` 15.0), copies resource bundles, and ad-hoc signs it. The app opens a window titled fabrikater. Use `@ViewState` (a typealias for `SwiftUI.State`) instead of `@State`; see [macos-tooling.md](macos-tooling.md).

Done in the foundation session, together with the `FabrikaterCore`, `AppUI` and `fabrikater` targets, `scripts/check.sh`, CI and the docs in [structure.md](structure.md) and [decisions/](decisions/).

CI-verifiable: `scripts/check.sh` passes on Linux and on macOS under the Command Line Tools; `scripts/bundle.sh` builds the app; `codesign -dv` reports `Signature=adhoc` and identifier `sh.bayram.fabrikater`; the app is still running 5 s after `open`.

Manual on the Mac: `scripts/check.sh`; `scripts/bundle.sh && open build/fabrikater.app` shows an empty split window titled fabrikater; `codesign -dv build/fabrikater.app` reports an ad-hoc signature.

## M1: SSH layer and the herd sidebar

`HostKit`'s `HostCommandRunner`, with the real implementation running one-off commands over a ControlMaster connection and long-lived streaming commands (the options are in [architecture.md](architecture.md)), and a replay implementation over fixtures. In `HerdrKit`, a `Herd` model decoded leniently from `herdr api snapshot`, the events channel, and `SendPolicy`. In `AppModel`, the first store. The sidebar shows workspaces, tabs and panes with status dots and labels, refreshed from the events channel with the safety poll.

CI-verifiable: the snapshot decodes leniently from `Tests/Fixtures/snapshot.synthetic.json` and from the captured `Tests/Fixtures/snapshot.json`, including unknown fields and statuses; the argument builder produces the exact ssh argument vectors and rejects invalid ids; the replay runner serves fixtures; the sidebar store orders workspaces, tabs and panes by `number`, collapses single-pane tabs, falls back through the labels, and keeps the last herd when a refresh fails; an event triggers one debounced refresh; `SendPolicy` follows `FABRIKATER_SEND_ALLOWLIST` as architecture.md, "Send allowlist", defines it (listed labels only; set but empty refuses all; unset means `fabrikater-test` in debug and no limit in release), checks the label against a fresh snapshot, and refuses when that read fails or the pane is missing.

Manual on the Mac (after `scripts/bundle.sh`): the sidebar lists the same workspaces and panes as `ssh arch herdr api snapshot | jq '.result.snapshot.workspaces[].label'`; a pane's status dot changes within about 2 s when the agent in it starts or finishes work; `FABRIKATER_FIXTURES=Tests/Fixtures build/fabrikater.app/Contents/MacOS/fabrikater` (the bundled release binary; `open` does not pass the variable on) shows the fixture herd without touching the host.

## M2: Claude conversation, read-only

Session log resolution and the Claude JSONL parser from [parsing.md](parsing.md), with the tail window, backfill on scroll-up, and the live `tail -F` follow. The conversation view renders user turns, markdown assistant text, tool rows with expandable input and result, summaries and notes.

CI-verifiable: parser tests against real JSONL fixtures copied from the host (two or three sessions, trimmed and scrubbed; add their capture to `scripts/capture-fixtures.sh`) and against Collie's test cases: role classification, tool-result folding, `isMeta` handling, `message.id` grouping, a clipped first line and a partial last line; the byte-offset tailer's carry handling; log resolution, including the conversation-root heuristic; the conversation store's paging and live append.

Manual on the Mac: open a Claude pane that is `working`; new assistant messages and tool rows appear within about 2 s of Claude writing them, without the scroll position jumping when the user has scrolled up; scrolling to the top loads older history.

## M3: Composer and sending

The composer with per-pane drafts, Return to send, the key bar, and the send sequence and race guard from [parsing.md](parsing.md).

CI-verifiable: drafts are kept per pane and survive a relaunch; Return sends and Shift-Return inserts a newline; the composer clears only after a successful send and keeps the text with an error on failure; user text travels only on stdin (the argument vector never contains it); the send sequence and its race guard follow parsing.md 4.4 against screen fixtures; `SendPolicy` blocks sends outside `fabrikater-test`.

Manual on the Mac: in the scratch pane (see [../CLAUDE.md](../CLAUDE.md)), start `claude` and send a one-line and a multi-line prompt from the app; both are submitted (the pane goes `working`) and appear in the conversation view. Esc and Ctrl-C from the key bar reach the pane. Record which of `pane send-text` and `agent prompt` submits multi-line text correctly in architecture.md.

## M4: Terminal view

SwiftTerm view fed from the polled `herdr pane read … --format ansi`, only while visible, with the Conversation | Terminal toggle.

CI-verifiable: the terminal store polls only while visible and stops when hidden (tested with a fake clock and runner); the pane read's argument vector; SwiftTerm compiles in the macOS job.

Manual on the Mac: the terminal view of the scratch pane matches what Herdr shows there, with colours, and polling stops (no `herdr pane read` processes on the host) when the view is hidden.

## M5: Prompt cards

Prompt detection for Claude Code's permission prompt and `AskUserQuestion`, rendered as cards, with guarded answering. The fallback card for anything unparsed.

CI-verifiable: grammar tests against captured `--source visible` screen fixtures and Collie's pane fixtures: the permission prompt, a single `AskUserQuestion`, a declined or unsure screen yielding no block; the guard refuses to send when the screen changed.

Manual on the Mac: capture the screen fixtures from the scratch pane; make Claude ask for permission to run a command (for example ask it to run `ls` with a permission mode that asks) and answer from the card; make it ask a multiple-choice question and answer from the card.

## M6: Notifications and "Needs you"

The "Needs you" group, Dock badge, and notifications on `blocked` and `working` to `done`.

CI-verifiable: the "Needs you" store: which panes it lists, in which order, how they leave it when opened, and the badge count; which status transitions notify, and when the pane is selected and the app frontmost, that none do.

Manual on the Mac: with the app in the background, a scratch-pane agent finishing a turn produces a notification; clicking it selects that pane; the Dock badge matches the "Needs you" group.

## M7: Other agents

Parsers for Codex, pi/omp and OpenCode logs, in the order and with the rules in [parsing.md](parsing.md). Panes of an agent without a parser open in the Terminal view by default.

CI-verifiable: parser tests for Codex, pi/omp and OpenCode against scrubbed host fixtures and Collie's cases; panes of an agent without a parser default to the Terminal view.

Manual on the Mac: a Codex pane's conversation renders its user turns, assistant text and tool calls.

## Later

The Settings scene from design.md (host alias, notifications, Return-to-send, font sizes); creating and closing tabs and panes; starting agents; search across all conversations; a `MenuBarExtra` with the "Needs you" list; image attachments in the composer.
