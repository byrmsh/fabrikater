# Checks on the Mac

Every check from the merged PRs that only the Mac or the host can do, most important first. Checks the macOS CI flows already prove with fixtures (docs/e2e.md) are left out. Tick an item when it passes; when one fails, note what you saw next to it. The PR each item came from is in brackets.

## 0. Setup

- [ ] `git pull && scripts/check.sh && scripts/bundle.sh` on `main`.
- [ ] `ssh arch true` works without a prompt, and the host has `herdr` and `socat` on its non-interactive `PATH` (README, "Run locally").
- [ ] A scratch workspace for sends exists: on the host, `herdr workspace create --label fabrikater-test --no-focus`, then start `claude` in its pane. Every send and prompt check below uses only that pane.
- Against the host: `open build/fabrikater.app`. Offline, with fixtures: `FABRIKATER_FIXTURES=Tests/Fixtures build/fabrikater.app/Contents/MacOS/fabrikater`. Each section says which.

## 1. Capture real fixtures (unblocks tests)

- [ ] `scripts/capture-fixtures.sh`, then `git diff --stat Tests/Fixtures`, skim `Tests/Fixtures/claude-capture-*.jsonl` for anything personal, and commit. [#35]
- [ ] `cat Tests/Fixtures/claude-tools.txt` and paste it into a thread: it says whether the plan panel should read `TodoWrite` or newer `Task*` tools [#21], and whether edit tools beyond Edit, MultiEdit and Write (NotebookEdit) are in use [#24].

## 2. Live herd and conversation (host)

- [ ] The sidebar lists the same workspaces as `ssh arch herdr api snapshot | jq '.result.snapshot.workspaces[].label'`. [#4]
- [ ] Status dot speed: send the scratch `claude` a prompt from Herdr and watch its dot. About 2 s means the fixed event subscription works; about 20 s means only the poll caught it and per-pane subscriptions are needed. [#4]
- [ ] Selecting a pane switches Herdr's screen to it within about half a second; holding ⌘↓ focuses only the pane it stops on; going back to a pane shows no loading spinner. [#7]
- [ ] On a `working` Claude pane, new messages and tool rows appear within about 2 s. [#30]
- [ ] Scroll up while it works: the view does not jump when rows arrive. [#30]
- [ ] `ssh arch pgrep -af 'tail -c 65536 -F'` shows one tail per open conversation, and none after selecting a shell pane or closing the pane window. [#30]
- [ ] On a long log, scroll to the top and press Load Earlier Messages: older messages appear; note whether the scroll position jumps. [#34]
- [ ] `claude --resume` in the scratch pane while the app shows it: the app keeps following the conversation as it grows. `ssh arch 'grep -l continued-in ~/.claude/projects/*/*.jsonl | head'` says whether hand-over rows exist yet. [#32]
- [ ] On a real session, the plan panel matches Claude's own todo list [#21], ⌘I's model, branch and context match Claude Code's status line [#22], and Show Changes (⌥⌘0) lists what the agent changed [#24].
- [ ] Markdown replies: text can be selected within a block; a compaction summary shows 4 lines plus Show All. [#31, #17]
- [ ] A row shows "now" after its turn starts or ends, then "1m", "2m"…; with View › Sort Panes By › Recent Activity, a pane that finishes a turn moves to the top, and the choice survives a relaunch. [#19, #25]
- [ ] Select the scratch pane, let another Claude pane finish a turn: its row shows the unread dot, and clicking it clears it. The dot reads well with a non-blue accent colour. [#20]
- [ ] Turn off Wi-Fi: the footer says offline and the sidebar keeps the last herd. [#4]
- [ ] Connection loss (#57). With a Claude conversation and the terminal view open, turn Wi-Fi off for a minute: within about a minute the footer says "Offline, showing the last known state", the conversation says "Live updates stopped: … Reconnecting…" above the last messages, and the terminal keeps its last screen marked stale. `pgrep -fl cm-fabrikater | wc -l` stays small (one master plus one ssh per open feed) the whole time. Turn Wi-Fi on: within about 30 s everything is live again with no relaunch, and the conversation's note goes away.
- [ ] Sleep and wake (#57). With a `working` pane selected, sleep the Mac (Apple menu › Sleep) for at least two minutes, then wake it: the footer says Connected and new rows appear within a few seconds, not a minute. `log show --last 5m --predicate 'subsystem BEGINSWITH "sh.bayram"' | grep -E "woke|shared connection"` shows "woke from sleep; reconnecting" and "closed the shared connection".
- [ ] After either check above, `ssh arch pgrep -af 'tail -c 65536 -F'` shows one tail per open conversation, not one per reconnect. [#57]

- [ ] Scale, offline with fixtures (docs/performance.md): `d=$(mktemp -d); cp Tests/Fixtures/snapshot-scale.synthetic.json "$d/snapshot.synthetic.json"; cp Tests/Fixtures/events.synthetic.jsonl "$d"; cp Tests/Fixtures/claude-scale.synthetic.jsonl "$d/claude.synthetic.jsonl"; FABRIKATER_FIXTURES="$d" build/fabrikater.app/Contents/MacOS/fabrikater`, then ⌘↓. Scrolling from the latest reply to the top and back stays smooth, typing `retry` in ⌘F does not stutter, and Load Earlier Messages reads the whole log without a beachball. [#59]
- [ ] Scale, on the host: with a long conversation open on a `working` Claude pane, Activity Monitor shows fabrikater under about 10% CPU while rows stream in. [#59]

## 3. Sending (scratch pane only)

- [ ] A one-line prompt is submitted (the pane goes `working`). [#7, #37]
- [ ] A multi-line prompt (⌥Return between lines) arrives as one message and is submitted. [#7, #37]
- [ ] Type into Claude's box in Herdr, then send from the app: refused with "already holds …", nothing appended. [#37]
- [ ] Ask Claude to run a command that needs permission: while the prompt shows, sending is refused with the question named. Answer it in Herdr, then send: it is submitted. [#13, #37]
- [ ] `ssh arch herdr pane read <scratch pane> --source visible --format ansi` on that prompt ends with a footer like `Esc to cancel · Tab to amend`; if not, capture it into `Tests/Fixtures/panes/`. [#13]
- [ ] Key bar: Esc while Claude works stops it; ⌃C at the idle prompt shows its exit hint; during a permission prompt only Esc and ⌃C are enabled and Esc dismisses it. [#40]
- [ ] In a pane window, ⌘Return sends that window's draft, not the main window's. [#29]

## 4. Prompt cards (scratch pane only)

- [ ] Ask Claude to run `mkfifo x`: the card shows "Permission Needed", the command and three options; "No" closes Claude's prompt and the card. [#41]
- [ ] Ask Claude to use AskUserQuestion with three options; pick one on the card and Claude continues with that answer (checks that Herdr takes `"2"` as a key). [#41]
- [ ] With a prompt showing, answer it in Herdr, then press an option in the app: nothing is sent and the card says the prompt changed. [#41]

## 5. Terminal view (scratch pane, then a split pane)

- [ ] ⌘T matches what Herdr shows, with colours. [#38]
- [ ] While it polls, the pane's own terminal in Herdr does not scroll; after ⌘T back, `ssh arch 'pgrep -af "herdr pane read"'` shows no reads left. [#38]
- [ ] Scroll up while the agent works: the view holds still and catches up at the bottom. [#38]
- [ ] On a pane split in Herdr, the terminal is exactly as wide as the pane at every ⌘+/⌘− size. With fixtures, the shell pane's long line scrolls with a two-finger sideways swipe. [#42]
- [ ] A failed read shows the stale banner. [#45]

## 6. Notifications, Needs You and the Dock

- [ ] App in the background, scratch agent finishes a task: a "Finished its turn" notification (macOS asks for permission the first time); clicking it brings fabrikater forward on that pane. [#43]
- [ ] Scratch agent asks for permission: a "Needs input" notification, and the pane is in Needs You. The Dock badge equals the Needs You rows. [#43]
- [ ] Turn Off Notifications on the scratch workspace heading silences it; Turn On brings it back. [#43]
- [ ] The menu bar bell shows the same count as the Dock badge, badged while panes wait and plain when none do; it reads well in a light and a dark menu bar and next to other items. [#54]
- [ ] Choosing a pane from the bell's menu while another app is in front brings fabrikater forward on that pane, un-minimising the main window if it was minimised. [#54]
- [ ] ⌘-drag the bell out of the menu bar: Settings › Show Needs You in the menu bar turns off, and turning it on brings the bell back. After a host switch (section 9) the bell's heading names the new host. [#54]
- [ ] Settings (⌘,): turning off "When an agent finishes its turn" stops those notifications; turning off the sound makes them silent. [#48]

## 7. Other agents (host, if any are running)

- [ ] A Codex pane renders its turns, replies and tool calls; so do an omp or pi pane and an OpenCode pane. [#44]
- [ ] A shell pane opens in the terminal; a Claude pane after it opens in the conversation. [#44]
- [ ] Captures of a Codex rollout, a pi or omp log and an OpenCode session would confirm codex's `custom_tool_call` shape, omp's `kind:"path"` and the OpenCode queries; there is no scrub step for them yet. [#44]

## 8. Windows, menus and past sessions

- [ ] Opening the same pane in a new window twice brings the first window forward; selecting another pane in the main window leaves the pane window on its own pane; after a relaunch, the pane window comes back and fills in. [#26]
- [ ] In a pane window in front, ⌥⌘0, ⌘I and Pane › Load Earlier Messages act on it; click the main window and they act there, with the Show Changes checkmark following. [#33, #45]
- [ ] ⌘Y on a Claude pane in a folder with hundreds of logs lists them quickly, newest first; opening the same one twice brings its window forward. [#46]
- [ ] ⌘Y on a Codex pane lists only that project's rollouts, quickly; on an omp or pi pane, its folder's sessions titled by first prompt; on an OpenCode pane, its directory's sessions with OpenCode's titles. `ssh arch "sqlite3 -readonly ~/.local/share/opencode/opencode.db '.schema session'"` shows `directory`, `title` and `parent_id`. [#50]
- [ ] ⌘F on a long real conversation: typing stays smooth, matches are highlighted in yellow in text, code blocks and tool rows, the current message has an accent outline, ⌘G and ⇧⌘G (and Shift-Return in the field) step and scroll to each, and Edit › Find lists the three items with no second Find menu. In a pane window and a past-session window ⌘F finds in that window. [#53]
- [ ] Panels (fixtures are enough): drag the left panel column's divider and the inspector's edge, and neither squeezes the conversation below its minimum; with a panel on the left in the main window, hiding and showing the sidebar (⌃⌘S) keeps both columns; a right-click on a panel's header offers Hide, Move Up and Move Down and the three places; opening and closing the left column keeps the conversation's scroll position. In light and dark mode the plan strip above the conversation reads as before, and the headers' ⋯ buttons are legible. [#56]
- [ ] Move a panel in a pane window, then open another pane in a new window: the new one starts with that arrangement, the main window keeps its own until the next launch. [#56]
- [ ] In a past-session window, ⌘R reloads and ⇧⌘C copies that session; Send and Show Terminal are disabled; ⌘↓ still moves the main window's selection. [#49]

## 9. Settings

- [ ] Set the host to another alias, quit and reopen: the sidebar shows that host's herd. [#48]
- [ ] The Text Size steppers change conversation and terminal text in open windows. [#48]
- [ ] In Settings, type another working alias and press Return: the sidebar shows that host's herd within a few seconds, and open pane or past-session windows close. [#52]
- [ ] After switching, `ps -ef | grep "ssh .*<old alias>"` shows no ssh processes left for the old host, once in-flight sends have finished. [#52]
- [ ] Quit and reopen: the app opens on the host you connected to. [#52]

## 10. VoiceOver and keyboard (fixtures are enough)

Run with fixtures: `FABRIKATER_FIXTURES=Tests/Fixtures build/fabrikater.app/Contents/MacOS/fabrikater`. Turn VoiceOver on and off with ⌘F5. [#58]

- [ ] With the prompt-card flow's fixtures: `d=$(mktemp -d); cp Tests/Fixtures/{events,claude,requests}.synthetic.jsonl Tests/Fixtures/screen-w1-p1.synthetic.txt "$d"; cp Tests/Fixtures/snapshot-prompt.synthetic.json "$d/snapshot.synthetic.json"; FABRIKATER_FIXTURES="$d" build/fabrikater.app/Contents/MacOS/fabrikater`, then ⌘↓: VoiceOver says "Permission Needed. Do you want to proceed?" as the card appears; ⌃⌥→ into the card reads each option by its label, and its hint says which key it presses.
- [ ] ⌃⌥→ through the key bar: "Send Key, group", then Escape, Control-C, Tab, Shift-Tab, Up Arrow, Down Arrow, Return. The Send button reads Send (or Queue).
- [ ] Against the host, with the scratch `claude` pane selected, send it a prompt that makes it ask permission while another pane is selected: VoiceOver says "<name> needs input" once, and the Dock badge counts it.
- [ ] Turn Wi-Fi off until the footer says Offline: VoiceOver says "Offline, showing the last known state"; turn it back on: "Reconnected".
- [ ] ⌃⌥U (rotor) › Headings lists each docked panel's title; a panel reads as a group named Plan, Changes or Session Info.
- [ ] ⌘, then Tab to the Text Size steppers: "Conversation Text Size, 13 pt"; ⌃⌥↑ says the new size.
- [ ] System Settings › Accessibility › Display › Differentiate without color: the sidebar's dots turn into shapes (ellipsis, exclamation mark, check, outline) and stay aligned with the labels; turning it off brings the dots back.
- [ ] System Settings › Keyboard › Keyboard navigation (Full Keyboard Access) on: Tab from the composer reaches the key bar, Send, the prompt card's options and the panel ⋯ menus, each with a visible focus ring; Space presses them.
- [ ] VoiceOver on the terminal view (⌘T): note what it reads (SwiftTerm's own accessibility); it should at least say Terminal.

## 11. Once, when convenient

- [ ] VoiceOver (⌘F5) through the sidebar: pane rows read name, agent, status; Show All and the key bar keys read by name. [#10, #17, #40]
- [ ] Whether plain ⌘= enlarges text as well as ⌘+. [#12]
- [ ] Pane › Open Folder in VS Code opens the folder on the host over Remote-SSH. [#16]
- [ ] Right-click a workspace heading › Hide Workspace works (a context menu on a section header). [#18]
- [ ] `scripts/e2e.sh conversation` runs locally once the terminal has Accessibility and Screen Recording access; `open build/e2e`. [#6, #47]
- [ ] Only if you restart the Herdr server anyway: a renamed pane keeps its name afterwards (tells whether pane ids survive a restart). [#8]
