# 0007: The M1 prototype's targets and data flow

Status: accepted (M1 prototype session, 2026-09-26)

## Context

M1 brings the first host code. The user asked for a working prototype end to end in one PR: the live sidebar, and selecting a pane shows its whole Claude session from the JSONL log in the same view (a live Herdr canvas may merge into that view later). The structure planned in [../structure.md](../structure.md) had `HostKit`, `HerdrKit` and `AppModel` in M1 and `TranscriptKit` in M2.

## Decision

- **Four new targets:** `HostKit`, `HerdrKit`, `TranscriptKit` and `AppModel`, each with a test target, declared through one `library(_:dependencies:)` helper in `Package.swift`. `TranscriptKit` arrives in M1 with the minimal slice: one read of the log's last 512 KB, the Claude parser, and a reload when the pane's status changes. Backfill, the live `tail -F` follow and hand-over resolution stay in M2.
- **One enum for host commands.** `HostCommand` holds every remote script, its timeout, whether it streams, and its replay fixture names. `SSHArguments` turns a command into the ssh argument vector. A new command is one new case.
- **Runners are the seam.** `SSHRunner` (real, `Process` plus `/usr/bin/ssh`) and `ReplayRunner` (fixture files) both implement `HostCommandRunner`. Everything above talks to a runner, so `FABRIKATER_FIXTURES` swaps the whole host out.
- **Events are pokes into one feed.** `HerdFeed` (an actor in `HerdrKit`) merges a safety poll (20 s) and the event channel into one `AsyncStream<HerdUpdate>`. Events within 250 ms of the first cause one snapshot read. The subscription is one fixed list of topology and pane events, not per-pane `pane.agent_status_changed` (the open question in M1).
- **Stores take streams and protocols.** `AppStore` consumes the `AsyncStream<HerdUpdate>` and gets a `TranscriptService`; tests pass a finished stream and a fake. `AppUI` also imports `TranscriptKit`, to render the transcript value types without re-wrapping them in `AppModel`.
- **Selection is read-only.** Selecting a pane in the app does not move Herdr's focus: the docs keep the app from mutating live panes, and focus-follows-selection waits for the user's explicit approval. (Superseded by [0008](0008-app-drives-live-panes.md): the user approved it.)

## Consequences

- The whole data path (ssh, decode, refresh, stores) is tested on Linux, including real local processes for timeouts and streaming.
- `ChildProcess` completes on the exit status plus a short drain, never on stderr's EOF, because ssh's backgrounded ControlMaster can hold stderr open. It escalates SIGTERM to SIGKILL after a second.
- The conversation reloads the 512 KB tail when the pane's status changes and on ⌘R; while a turn runs it shows the state at the turn's start until M2's live follow lands.
- If the fixed subscription misses status changes, the 20 s poll still catches them; the manual check on the Mac decides whether per-pane subscriptions are needed.
