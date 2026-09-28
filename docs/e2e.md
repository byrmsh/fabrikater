# End-to-end flows

`scripts/e2e.sh` launches the bundled app over fixtures (never the host), drives it through a few flows, checks what is on screen through the Accessibility API, and saves a screenshot of the window at each checkpoint. CI's macOS job runs it after `scripts/bundle.sh` and uploads `build/e2e/` as the `e2e-screenshots` artifact. It is how an agent with no Mac sees the app working ([decisions/0008](decisions/0008-e2e-screenshot-flows.md)).

## What runs

| Flow | Checks | Screenshot |
|---|---|---|
| `sidebar` | the synthetic herd's workspaces and panes carry accessible names, the footer says Connected, nothing is selected | `sidebar.png` |
| `conversation` | Next Pane (⌘↓) selects the first Claude pane and its conversation renders from `claude.synthetic.jsonl` | `conversation.png` |
| `room` | the toolbar says "Claude, Working" for the selected pane, ⌃⌘S hides the sidebar, ⌘+ twice enlarges the conversation's text, and ⌘0 plus ⌃⌘S bring both back | `room.png` (sidebar hidden, text two steps bigger) |
| `switcher` | ⌘K lists every pane with its location, Esc closes it, typing `codex` narrows it to the Codex pane and Return opens that pane, which has no session yet | `switcher.png`, `switcher-search.png`, `switcher-chosen.png` |
| `rename` | Rename… (⌘⇧R) on the selected pane, typed name and Return: the row shows the name instead of Herdr's label | `rename-editing.png`, `rename.png` |
| `composer` | typing a prompt and pressing Return sends it to the selected pane and clears the draft (the replay host shows the typed text in the input box, so the send guard sees it arrive) | `composer-draft.png`, `composer-sent.png` |
| `send-guard` | with a permission prompt on the pane's screen (`screen-w1-p1.synthetic.txt`), Return sends nothing and the draft stays with the reason | `send-guard.png` |
| `prompt-card` | a blocked Claude pane (`snapshot-prompt.synthetic.json`) with a permission prompt on its screen (`screen-w1-p1.synthetic.txt`) shows the card with the command and the question; choosing No sends its key, and since the replay host keeps the prompt, the card says it is still showing | `prompt-card.png`, `prompt-card-answered.png` |
| `prompt-fallback` | the blocked Codex pane gets the card that offers no answer, and its Show Terminal button swaps the conversation for the terminal | `prompt-fallback.png`, `prompt-fallback-terminal.png` |
| `drafts` | a draft typed for a pane is still in its composer after the app is quit and relaunched | `drafts.png` |
| `key-bar` | the key bar's Escape sends to the pane and leaves the draft in the field | `key-bar.png` |
| `send-draft` | with text already in the agent's input box (`screen-draft.synthetic.txt`), Return sends nothing and the composer says the box holds text | `send-draft.png` |
| `copy` | Copy Conversation as Markdown (⌘⇧C) puts the conversation on the pasteboard as markdown, saved as `copy.md` | `copy.png` |
| `collapse` | a long prompt and a compaction summary (`claude-long.synthetic.jsonl`) start collapsed with Show All, and Show All expands one and offers Show Less | `collapse.png`, `collapse-expanded.png` |
| `plan` | a session with `TodoWrite` calls (`claude-todos.synthetic.jsonl`) shows its latest plan above the conversation, "2 of 4 done", the item in progress in its present-tense wording, and no subagent plan | `plan.png` |
| `changes` | Show Changes (⌥⌘0) on a session with edits (`claude-changes.synthetic.jsonl`) lists Uploader.swift ("5 lines added, 3 removed") and RetryTests.swift but not the rejected, pending or subagent edits, expanding Uploader.swift shows its diff lines, and the toolbar button closes the inspector | `changes.png`, `changes-expanded.png` |
| `pinning` | Pin (⌘⇧P) on the selected pane adds a Pinned section above the workspaces, the pin survives a relaunch, and Unpin removes the section | `pinning.png`, `pinning-unpinned.png` |
| `hiding` | Hide Pane (Pane menu) drops the selected pane's row, turning off View › Show Shell Panes drops the shell pane, both survive a relaunch, and View › Show Hidden Panes brings the pane back read as hidden | `hiding.png`, `hiding-shown.png` |
| `unread` | swapping in `snapshot-later.synthetic.json` (the refactor pane's turn ends) marks that unselected row Unread, the mark survives a relaunch, and selecting the pane clears it | `unread.png`, `unread-read.png` |
| `needs-you` | the blocked Codex pane is in the Needs You group from launch; swapping in `snapshot-later.synthetic.json` (the refactor pane's turn ends) adds that pane, and ⌘2 opens it, which reads it and takes it out of the group | `needs-you.png`, `needs-you-opened.png` |
| `vscode` | Open Folder in VS Code is disabled in the Pane menu until a pane with a known folder is selected (never chosen, so no VS Code starts) | `vscode.png` |
| `facts` | Session Info (⌘I) opens a popover on the toolbar's status item with the model, folder, branch and context used from `claude-facts.synthetic.jsonl`, and Esc closes it | `facts.png` |
| `activity` | no row shows an activity time at launch; once a later herd (`snapshot-later.synthetic.json`, swapped in for the next 20 s poll) shows the refactor pane done, its row reads "Active just now" | `activity.png` |
| `sorting` | with View › Sort Panes By › Recent Activity, swapping in `snapshot-codex.synthetic.json` (the Codex pane's revision changes) moves the Codex row above the refactor pane in its workspace, and Herdr Order puts it back | `sorting.png`, `sorting-herdr.png` |
| `follow` | lines appended to the session log's fixture (`claude-follow.synthetic.jsonl`) appear in the open conversation without a reload, and a pane window opened on the same pane shows the next appended line (`claude-follow-more.synthetic.jsonl`) too | `follow.png`, `follow-window.png` |
| `window` | Pane › Open in New Window on the selected pane opens a second window with its conversation and toolbar status ("Claude, Working") and no sidebar; typing in its composer and pressing Return sends and clears the draft | `window.png`, `window-sent.png` |
| `window-panels` | with a pane window in front, Rename… is disabled, Show Changes (⌥⌘0) opens that window's changes inspector (`claude-changes.synthetic.jsonl`), and Session Info (⌘I) opens its facts popover (`claude-facts.synthetic.jsonl`), Esc closing it | `window-changes.png`, `window-facts.png` |
| `markdown` | an agent reply (`claude-markdown.synthetic.jsonl`) renders its heading, numbered and nested lists, code block, table and quote as blocks, with no `##` or table delimiter row left as text | `markdown.png` |
| `highlight` | an agent reply with Swift, shell, Python, TypeScript, JSON and diff code blocks (`claude-code.synthetic.jsonl`) shows each block's code with no fence left as text, in light mode and relaunched in dark mode; the colours are checked by eye | `highlight.png`, `highlight-dark.png` |
| `backfill` | a log longer than the first read (`claude-backfill.synthetic.jsonl`, 686 KB) starts clipped with Pane › Load Earlier Messages enabled; choosing it reads the whole log, so Copy Conversation now holds the first prompt, and the item turns disabled | `backfill.png` |
| `terminal` | View › Show Terminal is enabled once a pane is selected; ⌘T hides the conversation and shows the pane's terminal (`screen-w1-p1.synthetic.txt`, a permission prompt) with no "Terminal Unavailable", ⌘T brings the conversation back; relaunched in dark mode, selecting the shell pane opens its terminal (`terminal-w1-pA.synthetic.txt`, coloured prompt, `git status` and `ls`) without ⌘T; the colours are checked by eye | `terminal.png`, `terminal-shell-dark.png` |
| `agents` | on `snapshot-agents.synthetic.json`, the Codex pane chosen with ⌘K shows its conversation from `codex.synthetic.jsonl` (a reply, its shell and `apply_patch` calls, the final answer), the omp pane, whose session Herdr reports as a path, shows `pi.synthetic.jsonl`, the OpenCode pane shows `opencode.synthetic.jsonl` (the lines SQLite prints for it), and the shell pane opens in its terminal with Show Terminal disabled | `agents-codex.png`, `agents-omp.png`, `agents-opencode.png`, `agents-shell.png` |
| `past-sessions` | Pane › Past Sessions… is disabled with nothing selected; with the refactor pane selected, ⌘Y lists the sessions in `claude-sessions.synthetic.txt` by first prompt with the live one marked Current, and Return opens the highlighted one in a second window showing its conversation (`claude-00000000-0000-4000-8000-0000000000a1.synthetic.jsonl`) and no composer | `past-sessions.png`, `past-session-window.png` |
| `settings` | Settings (⌘,) shows the host ("Connected to arch"), the send key, the notification toggles and the text sizes; choosing Send with ⌘Return says Return starts a new line, typing `-bad` as the host says it is not an ssh alias; back in the main window, Return in the composer starts a second line instead of sending | `settings.png`, `settings-composer.png` |
| `offline` | with no snapshot fixture the sidebar says Offline and why, and does not claim a last known state | `offline.png` |

A failed step stops its flow and fails the job after the other flows ran. It leaves in `build/e2e/`: `<flow>-failure.png`, `<flow>-failure.txt` (every element in the window with its role and text attributes; the text checks search AXTitle, AXValue, AXDescription and AXHelp), `<flow>.log` (the app's output), `<flow>.ax.log` (the accessibility helper's errors) and `<flow>.osascript.log`. When a text check fails, read the `.txt` first.

## Adding a flow

A flow is one file, `scripts/e2e/flows/<name>.sh`, sourced with `set -euo pipefail` and the steps from `scripts/e2e/lib.sh`. Removing the file removes the flow. Keep one user-visible behaviour per flow.

```bash
# What the flow proves, in one line.
e2e_launch                          # the synthetic fixtures; or name files from Tests/Fixtures; --none for none
e2e_expect_label "Synthetic refactor, Claude, Working" # waits up to E2E_TIMEOUT (20 s) for what VoiceOver reads
e2e_key down command                # a key with modifiers, through System Events
e2e_expect_text "Rename the helper"
e2e_shot conversation               # build/e2e/conversation.png, just the window
```

Steps: `e2e_launch [fixture…|--none]` (`SOURCE=NAME` replays a fixture under another name, as the `collapse` flow does to show `claude-long.synthetic.jsonl` as the conversation; pane notes start empty; `E2E_KEEP_NOTES=1 e2e_launch` relaunches with the previous launch's notes), `E2E_DARK=1 e2e_launch` switches the system to dark mode for that launch, through System Events, and `e2e_quit` switches it back, `e2e_expect_text TEXT`, `e2e_expect_label TEXT` (an element VoiceOver reads as exactly TEXT, never a help tag), `e2e_expect_no_text TEXT` (checks once), `e2e_expect_no_label TEXT` (checks once that nothing reads as exactly TEXT, for text that also appears inside longer text), `e2e_disclose TEXT` (expands the disclosure triangle whose label holds a text reading exactly TEXT), `e2e_expect_gone TEXT` (waits for it to go), `e2e_key KEY [modifier…]` (a key, or text to type), `e2e_menu MENU ITEM` (clicks a menu bar item, for commands without a shortcut), `e2e_submenu MENU SUBMENU ITEM` (an item in a submenu), `e2e_expect_order FIRST SECOND` (waits until the element read as exactly FIRST comes before SECOND, as sidebar rows do top to bottom; each label's last element counts, so a copy in Needs You or Pinned is skipped), `e2e_focus_field PLACEHOLDER`, `e2e_click TITLE` (presses a control by its title, description or help tag), `e2e_expect_menu_item MENU ITEM enabled|disabled`, `e2e_expect_windows COUNT` (waits for the app to have COUNT windows; the newest is the front one, which the other steps read), `e2e_append_fixture FROM TO` (appends Tests/Fixtures/FROM to the running app's fixture TO, as an agent writing its log; the replay runner follows a log fixture every 250 ms), `e2e_swap_fixture FROM TO` (replaces the running app's fixture TO with FROM from Tests/Fixtures, read at the next 20 s poll, so wait with `E2E_TIMEOUT=45`), `e2e_shot NAME`, `e2e_screen_text` (prints the text the checks search), `e2e_screen_dump` (every element with its role and text attributes), and `e2e_wait WHAT COMMAND…` for anything else. Add a step to `lib.sh` when two flows would repeat the same osascript. Steps that read or press elements go through `build/e2e-ax`, compiled from `scripts/e2e/ax.swift` at the start of every run, because walking the window through System Events costs seconds per check ([decisions/0014](decisions/0014-native-e2e-accessibility-helper.md)); a new kind of tree query is a new command there.

`e2e_expect_focus TEXT` waits for a focused field holding TEXT, as before typing into a field that just opened.

`e2e_swap_fixture FROM TO` replaces a running app's fixture, as if the host changed; the app reads it at its next 20 s poll, so the check after it takes a longer `E2E_TIMEOUT`.

- Drive the app the way a person does: menu shortcuts from `Keymap`, typed text. No test-only switches in app code; if a flow cannot reach a state, add fixtures instead.
- Assert on text a person reads, as accessibility exposes it: `e2e_screen_dump` shows what that is. Plain `Text` is an AXStaticText with the text as AXValue.
- Find a sidebar row or heading by what VoiceOver reads (`e2e_expect_label "Synthetic refactor, Claude, Working"`, `e2e_expect_label "Synthetic A"`), not by its help tag. A pane row reads its label (the rename when set), agent and status (`PaneRow.spokenLabel`); a tab row its label and status. SwiftUI's sidebar headings (workspace sections and tab disclosure rows) drop their accessibility label and keep only the value, so those carry their text as the value.
- Every launch starts clean: it ignores saved window state (`-ApplePersistenceIgnoreState YES`) and clears the fixture defaults domain `sh.bayram.fabrikater.fixtures`, where `FABRIKATER_FIXTURES` runs keep pane names, so a flow that renames a pane, hides the sidebar or changes the text size cannot leak it into the next, and never touches the real pane names. `E2E_KEEP_NOTES=1 e2e_launch` skips the clearing, to check that notes survive a relaunch.
- Fixtures come only from `Tests/Fixtures`. A flow needing a new shape gets a new `*.synthetic.*` file there; `e2e_launch` copies just the named files so the replay runner cannot pick up another one.

## Looking at the screenshots

After pushing, find the macOS run on the PR, then with the GitHub tools: list the run's artifacts (`actions_list`, `list_workflow_run_artifacts`), get the `e2e-screenshots` download URL (`actions_get`, `download_workflow_run_artifact`), `curl -sSL -o e2e.zip "<url>"` it into the scratchpad, unzip, and read the PNGs. Compare them against docs/design.md and the `macos-design` checklist; a view change is not done until its screenshot looks right.

On the Mac: `scripts/bundle.sh && scripts/e2e.sh [flow…]`, then `open build/e2e`. The terminal running it needs Accessibility and Screen Recording access (System Settings › Privacy & Security); macOS asks on the first run.
