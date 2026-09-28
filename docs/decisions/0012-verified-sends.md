# 0012: Prompts are verified in the input box and checked on the host

Status: accepted (2026-09-28). Completes what [0009](0009-send-guard.md) left for M3.

## Context

[0009](0009-send-guard.md) reads the pane's screen before a prompt's text and again before its Enter, and refuses while a dialog's footer shows. Two gaps remained, both in [parsing.md](../parsing.md) 4.4. First, a dialog that appears in the ssh round trip between the app's read and the keystroke still gets the keys; in Claude Code a single digit picks a dialog option, so the text alone can answer it. Second, Enter went out whether or not the text had reached the input box: if something else took the text, Enter would confirm it. Collie closes both by verifying the draft in the input box before Enter and by re-reading the pane right before each keystroke.

## Decision

- **The host checks the screen right before each keystroke.** A `HerdrRequest` can be `.checked(ScreenCheck, request)`. `HerdrClient` writes the check ahead of the request on the requests script's stdin (`HostCommand.herdrRequests`): a `?<pane> <window> <p> <r>` line, then phrases and rows. The script reads the pane's visible screen, strips styling and spaces with `awk`, and sends the request only if none of the last three non-blank rows holds a dialog phrase and the given rows still show among the last `window` rows; otherwise it prints a `screen_changed` error reply and stops. Read, check and send are one remote command, so the gap left is the time `awk` takes. The rows can hold user text, so they travel on stdin and in the environment, never in an argument.
- **Claude Code's input box is read.** `PromptKit`'s `InputBox(on:)` finds the box by its frame (the lowest frame row is a bare bottom border, then the `❯` prompt row, then a top border), reads its draft with wrapped rows joined, treats all-faint text as Claude's suggested prompt rather than a draft, and says whether the box `carries` what was sent (the same characters with whitespace aside, or Claude's `[Pasted text #N +M lines]` placeholder for M newlines). It is a simplified port of Collie's `locateInputBox` and `extractInputDraft`.
- **`SendGuard` verifies a prompt when it sees the box.** Its text goes in only when the box is empty, checked on the host against the box's rows; then the guard reads the screen up to 8 times, 350 ms apart, and sends Enter only once the box carries the text, checked on the host against the box as it now shows. A box that already holds text refuses the send, since the prompt would be appended to it. Text that never shows gets no Enter. Screens without a box it knows (other agents, a shell) keep 0009's per-request dialog check, now also run on the host.
- **Fixture runs echo typed text.** `ReplayRunner` shows text sent to a pane on its screen fixture's prompt row until Enter, so the composer and its end-to-end flows work over fixtures; it does not run screen checks.

## Consequences

- A verified prompt costs one screen read before the text, one or more while waiting for it to show, and two host-side reads, one in each request's command.
- The check is stricter than Collie's substring match: the box must hold exactly what was sent. A Claude Code version that rewrites typed text (other than whitespace and the paste placeholder) would make every send stop before Enter with the text left in the box. That fails safe, and the error says to look at the pane.
- The host needs `awk`, and the script is POSIX `sh`. `RequestsScriptTests` runs it locally with a fake `herdr` and `socat`, and `SendGuardOnTheHostScriptTests` runs the whole guard over it with Collie's captures, so the Swift and `awk` normalisations are tested against each other.
- A modal Claude Code draws without footer hints and without an input box (a picker the hints miss) still gets a one-shot send; knowing the pane's agent would let the guard refuse there instead.
