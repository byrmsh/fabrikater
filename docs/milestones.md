# Milestones

Each milestone ends with a check a person can perform and see pass. Do them in order; each builds on the last. Commit at least once per milestone.

## M0: Toolchain and empty app

A SwiftPM package with one executable target and a `scripts/bundle.sh` that builds (`swift build -c release`, falling back to `--build-system native` if the default engine fails), assembles `build/fabrikater.app` with an Info.plist (`CFBundleIdentifier` `sh.bayram.fabrikater`, `LSMinimumSystemVersion` 15.0), copies resource bundles, and ad-hoc signs it. The app opens a window titled fabrikater. Use `@ViewState` (a typealias for `SwiftUI.State`) instead of `@State`; see [macos-tooling.md](macos-tooling.md).

Check: `scripts/bundle.sh && open build/fabrikater.app` shows the window; `codesign -dv build/fabrikater.app` reports an ad-hoc signature.

## M1: SSH layer and the herd sidebar

An `SSH` type that runs one-off commands over a ControlMaster connection and long-lived streaming commands, with the options in [architecture.md](architecture.md). A `Herd` model decoded leniently from `herdr api snapshot`. The sidebar shows workspaces, tabs and panes with status dots and labels, refreshed from the events channel with the safety poll.

Check: the sidebar lists the same workspaces and panes as `ssh archz herdr api snapshot | jq '.result.snapshot.workspaces[].label'`, and a pane's status dot changes within about 2 s when the agent in it starts or finishes work. Unit tests decode a captured snapshot fixture (capture one with `ssh archz herdr api snapshot > Tests/Fixtures/snapshot.json`, then replace any secrets or personal paths you do not want committed).

## M2: Claude conversation, read-only

Session log resolution and the Claude JSONL parser from [parsing.md](parsing.md), with the tail window, backfill on scroll-up, and the live `tail -F` follow. The conversation view renders user turns, markdown assistant text, tool rows with expandable input and result, summaries and notes.

Check: open a Claude pane that is `working`; new assistant messages and tool rows appear within about 2 s of Claude writing them, without the scroll position jumping when the user has scrolled up. Parser unit tests run against real JSONL fixtures copied from the host (pick two or three sessions, trim them, scrub anything private).

## M3: Composer and sending

The composer with per-pane drafts, Return to send, the key bar, and the send sequence and race guard from [parsing.md](parsing.md).

Check: in the scratch pane (see [../CLAUDE.md](../CLAUDE.md)), start `claude` and send a one-line and a multi-line prompt from the app; both are submitted (the pane goes `working`) and appear in the conversation view. Esc and Ctrl-C from the key bar reach the pane.

## M4: Terminal view

SwiftTerm view fed from the polled `herdr pane read … --format ansi`, only while visible, with the Conversation | Terminal toggle.

Check: the terminal view of the scratch pane matches what Herdr shows there, with colours, and polling stops (no `herdr pane read` processes on the host) when the view is hidden.

## M5: Prompt cards

Prompt detection for Claude Code's permission prompt and `AskUserQuestion`, rendered as cards, with guarded answering. The fallback card for anything unparsed.

Check: in the scratch pane, make Claude ask for permission to run a command (for example ask it to run `ls` with a permission mode that asks) and answer from the card; make it ask a multiple-choice question and answer from the card. Parser tests use captured `--source visible` screen fixtures.

## M6: Notifications and "Needs you"

The "Needs you" group, Dock badge, and notifications on `blocked` and `working` to `done`.

Check: with the app in the background, a scratch-pane agent finishing a turn produces a notification; clicking it selects that pane.

## M7: Other agents

Parsers for Codex, pi/omp and OpenCode logs, in the order and with the rules in [parsing.md](parsing.md). Panes of an agent without a parser open in the Terminal view by default.

Check: a Codex pane's conversation renders its user turns, assistant text and tool calls.

## Later

Creating and closing tabs and panes; starting agents; search across all conversations; a `MenuBarExtra` with the "Needs you" list; image attachments in the composer.
