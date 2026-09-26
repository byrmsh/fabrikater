# 0008: The app focuses and prompts live panes

Status: accepted (2026-09-26), supersedes the "Selection is read-only" point of [0007](0007-m1-prototype-targets.md)

## Context

After trying the M1 prototype the user asked for two things the docs held back: selecting a pane in the app should move Herdr's own focus to it, and the app should send prompts to the selected pane. Both change live panes, which the docs allowed only behind an explicit decision. The user's request is that decision. Development agents still never touch live panes (see [../../CLAUDE.md](../../CLAUDE.md)); this ADR is about what the app does when its user acts.

## Decision

- **One path for changes.** `HerdrRequest` (in `HerdrKit`) is every call that changes Herdr: `focus`, `sendText`, `sendKeys`. `HerdrControl.perform(_:)` runs a list of them. `HerdrClient` implements it with one ssh command, `HostCommand.herdrRequests`, which sends each request as a JSON line on stdin to Herdr's API socket, one connection per request (the socket answers one request per connection). User text is inside JSON on stdin, never on the command line.
- **Typing is policed, focus is not.** `PolicedControl` wraps any `HerdrControl` and asks `SendPolicy` (unchanged: `FABRIKATER_SEND_ALLOWLIST`, `fabrikater-test` only in debug builds, no limit in release) before any request that types into a pane. Focus types nothing, so it runs everywhere.
- **Focus follows the settled selection.** `FocusSync` (in `AppModel`) sends `pane.focus` 200 ms after the selection stops changing, so stepping through the sidebar with ⌘↓ focuses only the pane it lands on. Focus follows only the user's selection; nothing else in the app moves it.
- **A prompt is text, then Enter.** `HerdrRequest.prompt(_:to:)` trims the text and sends it with `pane.send_text`, then `Enter` with `pane.send_keys`, with a 0.3 s settle between them on the host. `pane.send_text` writes raw bytes, so multi-line text is wrapped in bracketed-paste markers to keep its newlines from submitting early.
- **Each feature is its own small module.** `FocusSync`, `ComposerStore` and `TranscriptCache` each sit in their own file behind the protocol they need; removing one is deleting its file and its line in `AppStore`.

## Consequences

- The composer is the first slice of M3: per-pane drafts in memory, Return (and ⌘Return from the menu) sends, "Queue" while the agent works, the draft kept with an inline error on failure. Collie's draft verification and race guard (parsing.md 4.4), drafts on disk and the key bar remain M3 work.
- Whether bracketed paste submits multi-line text correctly in Claude Code is checked on the Mac (milestones.md, M3).
- A debug build run on the Mac moves the user's Herdr focus when a live pane is selected. Agents testing on the Mac select only the scratch pane, or run with `FABRIKATER_FIXTURES`.
