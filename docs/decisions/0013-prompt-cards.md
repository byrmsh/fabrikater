# 0013: Prompt cards answer through their own guard

Status: accepted (2026-09-28). Builds on [0009](0009-send-guard.md) and [0012](0012-verified-sends.md).

## Context

M5 answers an agent's dialog from the app. [0009](0009-send-guard.md) says the answer path must not go through `SendGuard`, which refuses every key but Esc and Control-C while a dialog shows. Answering is a single digit, so a stale card could answer a different prompt that appeared since the app looked; Collie guards this by re-reading and re-parsing before a tap and binding the keys to the prompt's rows on the host (parsing.md 4.4).

## Decision

- **`PromptKit`'s `Prompt(on:)` is the only grammar**, a port of Collie's prompt-select for numbered prompts: permission, single `AskUserQuestion`, plan approval and folder trust. It declines everything else (wizards, multi-select, menus, the unnumbered trust list, a pointer on a typed-answer row), and a declined screen gets the card with no options. Nothing is ever guessed.
- **`PromptCardStore` in `AppModel`**, one per window, reads the screen when Herdr reports the selected pane `blocked` (and again when its revision changes), only for Claude panes. An answer re-reads the screen and sends only if the parsed prompt equals the one on the card, rows included, so the same question about a different command is a different prompt.
- **The keys go as one `.checked` request.** `pane.send_keys` gets the digit (Herdr's key grammar takes a single character as itself; `HerdrRequest.Key` is now a struct with `digit(_:)`), plus Enter for `AskUserQuestion`. The `ScreenCheck` wants the prompt's rows, question through footer, at the bottom of the screen, and no refusing phrases. After sending, the store polls 8 × 350 ms for the prompt to go and says so if it stays.
- **Composition:** answers use `PolicedControl(client, …)`: the workspace allowlist still applies, `SendGuard` does not.

## Consequences

- A second path types into panes. It sends only digits and Enter, only while the host sees the exact prompt that was parsed.
- The card without options offers Show Terminal, where the prompt is answered by hand.
- Grammars for the other dialogs are added in `PromptKit` one at a time, each with its own keys; the store and card need no change for a new numbered shape.
