# 0009: A screen check guards every prompt

Status: accepted (2026-09-26)

## Context

Since [0008](0008-app-drives-live-panes.md) the composer types into live panes. When the agent is showing a dialog (a permission prompt, an `AskUserQuestion`, a plan approval, a menu), the input box is gone and typed text goes to the dialog: a stray `1` or `y` plus Enter answers it. Herdr's `blocked` status says so, but it comes from a snapshot that can be seconds old, and a dialog can appear between reading it and typing. Collie avoids this by reading the screen right before a send and verifying the draft before Enter (docs/parsing.md 4.4).

## Decision

- **`PromptKit` exists now**, earlier than its planned M5, holding only `Screen` (ANSI text to plain lines) and `Dialog(on:)`, which looks for a dialog's key hints (`Enter to select`, `Tab to amend`, `Esc to cancel`, Codex's and Grok's footers) in the last three non-blank lines. The M5 grammars grow next to it. It depends only on `FabrikaterCore`, as planned.
- **`SendGuard` (in `AppModel`) wraps `HerdrControl`.** Before each request that types into a pane it reads the pane's visible screen (`HostCommand.herdrPaneScreen`, `herdr pane read <pane> --source visible --format ansi`, through `HerdrKit`'s `PaneReader`) and refuses if a dialog shows or the read fails. It performs requests one at a time, so the check also runs between a prompt's text and its Enter: a dialog that appeared while typing keeps the Enter from confirming it.
- **The composer also says so up front.** While Herdr reports the selected pane `blocked`, sending is off and the composer shows that the agent is waiting for an answer.
- **Composition order:** `PolicedControl(SendGuard(client, reader: client), …)`: the allowlist first, then the screen.

## Consequences

- A prompt costs two screen reads over the shared ssh connection, one before the text and one before Enter.
- The check is a footer match, not Collie's full draft verification. A gap of one ssh round trip remains between the last read and the keystroke; parsing.md 4.4 describes collapsing read, check and send into one remote snippet, and verifying the draft appeared before Enter. Both stay M3 work; [0012](0012-verified-sends.md) does them.
- Screens the check does not know (muse, omp, a Codex approval whose footer scrolled away) pass. Collie's captures in `Tests/Fixtures/panes/` pin what it knows; a new capture that shows a miss adds its hint.
- M5's answer path (sending a dialog's option keys) must not go through `SendGuard`, which would refuse it; it gets its own guard against the screen having changed (parsing.md 4.4).
