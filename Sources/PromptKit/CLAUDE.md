# PromptKit

What an agent's screen shows: plain text from `herdr pane read … --format ansi`, and the dialogs on it (docs/parsing.md section 4). Builds and tests on Linux.

- Pure functions from screen text to values: no I/O, tested against the pane captures in `Tests/Fixtures/panes/` (Collie's, scrubbed).
- `Dialog(on:)` answers one question today: would typed text land in a dialog instead of the input box? It reads only the footer's key hints, so a transcript quoting a dialog does not count. `InputBox(on:)` reads Claude Code's input box: its rows, its draft (a faint suggestion is none) and whether it `carries` what was sent (decisions/0012). `Prompt(on:)` reads Claude Code's numbered prompts (permission, single `AskUserQuestion`, plan, folder trust): family, question, subject, options, and the rows an answer is bound to (decisions/0013). Further grammars (wizard, multi-select, menus) grow here next to them, each declining what it cannot answer.
- Footer phrases change when agents update (docs/parsing.md 4.5). When a new capture shows a dialog the check misses, add the capture and its hint.
- Ported code keeps its Collie attribution header, and THIRD_PARTY_NOTICES.md stays current.
- Depends on `FabrikaterCore`.
