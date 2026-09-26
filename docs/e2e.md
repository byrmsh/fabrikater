# End-to-end flows

`scripts/e2e.sh` launches the bundled app over fixtures (never the host), drives it through a few flows, checks what is on screen through the Accessibility API, and saves a screenshot of the window at each checkpoint. CI's macOS job runs it after `scripts/bundle.sh` and uploads `build/e2e/` as the `e2e-screenshots` artifact. It is how an agent with no Mac sees the app working ([decisions/0008](decisions/0008-e2e-screenshot-flows.md)).

## What runs

| Flow | Checks | Screenshot |
|---|---|---|
| `sidebar` | the synthetic herd's workspaces and panes carry accessible names, the footer says Connected, nothing is selected | `sidebar.png` |
| `conversation` | Next Pane (⌘↓) selects the first Claude pane and its conversation renders from `claude.synthetic.jsonl` | `conversation.png` |
| `room` | the toolbar says "Claude, Working" for the selected pane, ⌃⌘S hides the sidebar, ⌘+ twice enlarges the conversation's text, and ⌘0 plus ⌃⌘S bring both back | `room.png` (sidebar hidden, text two steps bigger) |
| `composer` | typing a prompt and pressing Return sends it to the selected pane and clears the draft | `composer-draft.png`, `composer-sent.png` |
| `send-guard` | with a permission prompt on the pane's screen (`screen-w1-p1.synthetic.txt`), Return sends nothing and the draft stays with the reason | `send-guard.png` |
| `copy` | Copy Conversation as Markdown (⌘⇧C) puts the conversation on the pasteboard as markdown, saved as `copy.md` | `copy.png` |
| `collapse` | a long prompt and a compaction summary (`claude-long.synthetic.jsonl`) start collapsed with Show All, and Show All expands one and offers Show Less | `collapse.png`, `collapse-expanded.png` |
| `pinning` | Pin (⌘⇧P) on the selected pane adds a Pinned section above the workspaces, the pin survives a relaunch, and Unpin removes the section | `pinning.png`, `pinning-unpinned.png` |
| `vscode` | Open Folder in VS Code is disabled in the Pane menu until a pane with a known folder is selected (never chosen, so no VS Code starts) | `vscode.png` |
| `offline` | with no snapshot fixture the sidebar says Offline and why, and does not claim a last known state | `offline.png` |

A failed step stops its flow and fails the job after the other flows ran. It leaves in `build/e2e/`: `<flow>-failure.png`, `<flow>-failure.txt` (every element in the window with its role and text attributes; the text checks search AXTitle, AXValue, AXDescription and AXHelp), `<flow>.log` (the app's output) and `<flow>.osascript.log`. When a text check fails, read the `.txt` first.

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

Steps: `e2e_launch [fixture…|--none]` (`SOURCE=NAME` replays a fixture under another name, as the `collapse` flow does to show `claude-long.synthetic.jsonl` as the conversation; pane notes start empty; `E2E_KEEP_NOTES=1 e2e_launch` relaunches with the previous launch's notes), `e2e_expect_text TEXT`, `e2e_expect_label TEXT` (an element VoiceOver reads as exactly TEXT, never a help tag), `e2e_expect_no_text TEXT` (checks once), `e2e_expect_gone TEXT` (waits for it to go), `e2e_key KEY [modifier…]` (a key, or text to type), `e2e_focus_field PLACEHOLDER`, `e2e_click TITLE` (presses a control by its title, description or help tag), `e2e_expect_menu_item MENU ITEM enabled|disabled`, `e2e_shot NAME`, `e2e_screen_text` (prints the text the checks search), `e2e_screen_dump` (every element with its role and text attributes), and `e2e_wait WHAT COMMAND…` for anything else. Add a step to `lib.sh` when two flows would repeat the same osascript.

- Drive the app the way a person does: menu shortcuts from `Keymap`, typed text. No test-only switches in app code; if a flow cannot reach a state, add fixtures instead.
- Assert on text a person reads, as accessibility exposes it: `e2e_screen_dump` shows what that is. Plain `Text` is an AXStaticText with the text as AXValue.
- Find a sidebar row or heading by what VoiceOver reads (`e2e_expect_label "Synthetic refactor, Claude, Working"`, `e2e_expect_label "Synthetic A"`), not by its help tag. A pane row reads its label (the rename when set), agent and status (`PaneRow.spokenLabel`); a tab row its label and status. SwiftUI's sidebar headings (workspace sections and tab disclosure rows) drop their accessibility label and keep only the value, so those carry their text as the value.
- Every launch starts clean: it ignores saved window state (`-ApplePersistenceIgnoreState YES`) and clears the fixture defaults domain `sh.bayram.fabrikater.fixtures`, where `FABRIKATER_FIXTURES` runs keep pane names, so a flow that renames a pane, hides the sidebar or changes the text size cannot leak it into the next, and never touches the real pane names. `E2E_KEEP_NOTES=1 e2e_launch` skips the clearing, to check that notes survive a relaunch.
- Fixtures come only from `Tests/Fixtures`. A flow needing a new shape gets a new `*.synthetic.*` file there; `e2e_launch` copies just the named files so the replay runner cannot pick up another one.

## Looking at the screenshots

After pushing, find the macOS run on the PR, then with the GitHub tools: list the run's artifacts (`actions_list`, `list_workflow_run_artifacts`), get the `e2e-screenshots` download URL (`actions_get`, `download_workflow_run_artifact`), `curl -sSL -o e2e.zip "<url>"` it into the scratchpad, unzip, and read the PNGs. Compare them against docs/design.md and the `macos-design` checklist; a view change is not done until its screenshot looks right.

On the Mac: `scripts/bundle.sh && scripts/e2e.sh [flow…]`, then `open build/e2e`. The terminal running it needs Accessibility and Screen Recording access (System Settings › Privacy & Security); macOS asks on the first run.
