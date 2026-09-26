# End-to-end flows

`scripts/e2e.sh` launches the bundled app over fixtures (never the host), drives it through a few flows, checks what is on screen through the Accessibility API, and saves a screenshot of the window at each checkpoint. CI's macOS job runs it after `scripts/bundle.sh` and uploads `build/e2e/` as the `e2e-screenshots` artifact. It is how an agent with no Mac sees the app working ([decisions/0008](decisions/0008-e2e-screenshot-flows.md)).

## What runs

| Flow | Checks | Screenshot |
|---|---|---|
| `sidebar` | the synthetic herd's workspace and pane labels are listed; nothing is selected | `sidebar.png` |
| `conversation` | Next Pane (⌘↓) selects the first Claude pane and its conversation renders from `claude.synthetic.jsonl` | `conversation.png` |
| `offline` | with no snapshot fixture the sidebar says it is offline | `offline.png` |

A failed step stops its flow and fails the job after the other flows ran. It leaves in `build/e2e/`: `<flow>-failure.png`, `<flow>-failure.txt` (every title, value and description in the window, which is what the text checks search), `<flow>.log` (the app's output) and `<flow>.osascript.log`. When a text check fails, read the `.txt` first.

## Adding a flow

A flow is one file, `scripts/e2e/flows/<name>.sh`, sourced with `set -euo pipefail` and the steps from `scripts/e2e/lib.sh`. Removing the file removes the flow. Keep one user-visible behaviour per flow.

```bash
# What the flow proves, in one line.
e2e_launch                          # the synthetic fixtures; or name files from Tests/Fixtures; --none for none
e2e_expect_text "Synthetic refactor" # waits up to E2E_TIMEOUT (20 s) for text in the window
e2e_key down command                # a key with modifiers, through System Events
e2e_expect_text "Rename the helper"
e2e_shot conversation               # build/e2e/conversation.png, just the window
```

Steps: `e2e_launch [fixture…|--none]`, `e2e_expect_text TEXT`, `e2e_expect_no_text TEXT`, `e2e_key KEY [modifier…]`, `e2e_shot NAME`, `e2e_screen_text` (prints the window's text), and `e2e_wait WHAT COMMAND…` for anything else. Add a step to `lib.sh` when two flows would repeat the same osascript.

- Drive the app the way a person does: menu shortcuts from `Keymap`, typed text. No test-only switches in app code; if a flow cannot reach a state, add fixtures instead.
- Assert on text a person reads. Accessibility exposes `Text` as static text, so labels in the fixtures are the easiest anchors.
- Fixtures come only from `Tests/Fixtures`. A flow needing a new shape gets a new `*.synthetic.*` file there; `e2e_launch` copies just the named files so the replay runner cannot pick up another one.

## Looking at the screenshots

After pushing, find the macOS run on the PR, then with the GitHub tools: list the run's artifacts (`actions_list`, `list_workflow_run_artifacts`), get the `e2e-screenshots` download URL (`actions_get`, `download_workflow_run_artifact`), `curl -sSL -o e2e.zip "<url>"` it into the scratchpad, unzip, and read the PNGs. Compare them against docs/design.md and the `macos-design` checklist; a view change is not done until its screenshot looks right.

On the Mac: `scripts/bundle.sh && scripts/e2e.sh [flow…]`, then `open build/e2e`. The terminal running it needs Accessibility and Screen Recording access (System Settings › Privacy & Security); macOS asks on the first run.
