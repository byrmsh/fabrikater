# Design

This document says what the app looks like and how it behaves. [architecture.md](architecture.md) says where the data comes from; [parsing.md](parsing.md) says how raw logs and screens become the models used here.

## The problem it solves

The user runs dozens of agent sessions in Herdr on a host about 140 ms away. Working in them through a remote terminal means every scroll step and every keystroke waits on the network, and long sessions are painful to read. Herdr's workspace and tab organisation is valuable and must be kept. fabrikater shows the same organisation in a native window, renders each conversation locally, and lets the user reply without a remote terminal in the loop.

Non-goals: starting, closing or renaming panes, tabs and workspaces (Herdr's own UI does that; a later milestone may add it); editing files (VS Code does that); running on iOS; any server component on the host; replacing Herdr's TUI for the user's other work.

## Window

One main window, a standard macOS three-part `NavigationSplitView`:

1. **Sidebar: the herd.** Workspaces as sections in Herdr's order (by `number`), each listing its tabs, and under each tab its panes. Each row shows a status dot (`working` animated, `blocked` in an attention colour, `done` as unseen, `idle` quiet), the agent kind icon, and the pane label (`terminal_title_stripped`, falling back to the tab label, then the pane id). A tab with a single pane collapses to one row. Shell panes without an agent are shown dimmed and are selectable (terminal view only). A filter field at the top matches labels. A "Needs You" group pinned at the top lists every `blocked` pane, then every pane whose agent finished a turn (now `done` or `idle`) that has not been opened in the app since, each group in sidebar order, so a pane keeps its place until its own state changes. Opening a finished pane takes it out; a blocked pane stays until its agent moves on. Hidden panes are left out. The rows also stay in their workspaces, and ⌘↑/⌘↓ skip the group.
2. **Detail: the selected pane.** No header of its own: the window title is the pane label, the subtitle its workspace and tab, and the toolbar shows its status (dot and word) and agent kind next to Reload (clicking it, or Pane ▸ Session Info ⌘I, opens a popover with the session's model, folder, git branch, start time and context used), plus (from M4) a segmented control **Conversation | Terminal**. View ▸ Toggle Sidebar (⌃⌘S) hides the sidebar, and View ▸ Bigger, Smaller and Actual Size (⌘+, ⌘−, ⌘0) set the conversation's text size, both kept with the window. View ▸ Show Changes (⌥⌘0), also a toolbar button, opens an inspector on the right listing the files the session changed, each expanding to its edits as a diff. The detail shows the chosen view, and at the bottom the composer.
3. No third column in the first version.

The arrangement of these panels comes from a layout model in `AppModel`, not from the view hierarchy (`.claude/skills/macos-design`, `references/layout-model.md`). The first version has the fixed shape above; a later milestone makes panels movable and dockable, IDE-style (Xcode, Zed), without rewriting the views.

**Pane windows.** Open in New Window, in a pane row's context menu and the Pane menu, opens that pane's conversation in a window of its own (one per pane; opening it again brings it to the front). The window has no sidebar but its own composer, which sends to its pane and shares that pane's draft with the main window: its title and subtitle are the pane's label and location, its toolbar has the same status (with Session Info), Reload and Show Changes as the main window, each opening that window's own popover and inspector, and it follows the main window's text size. When Herdr no longer has the pane, the window keeps the last conversation and says so. Menu bar commands act on the front window: with a pane window in front, the Pane and View menus' pane commands (Pin, Hide Pane, Open Folder in VS Code, Reload, Copy Conversation, Session Info, Show Changes, Send) act on its pane, Rename… and Hide Workspace are disabled since they need the sidebar, and the sidebar's own commands (Next Pane, Open Quickly…, sorting, text size) still act on the main window. The line under the toolbar is the standard toolbar separator, drawn in the main window's detail too.

**Past sessions.** Pane ▸ Past Sessions… (⌘Y), also in a pane row's context menu, opens a sheet over the main window listing the sessions the pane's agent kept for the same working directory (Claude, Codex, pi and omp, OpenCode), like Safari's History: newest first, each row the session's first prompt, how long ago its log was written and its size, the live one marked Current. Sessions with no prompt yet (hand-over stubs, a session closed before its first message) are left out. Return, a double-click or Open opens the highlighted session in a window of its own (one per session, reopening brings it to the front) titled by its first prompt, with the conversation view, Load Earlier Messages, Copy Conversation and Reload in its toolbar, and no composer, since no pane runs it. With a pane window in front the item is disabled, since the sheet belongs to the main window. With a session window in front, the menu bar's conversation commands (Reload, Load Earlier Messages, Copy Conversation) act on that session, the pane's commands (Send, the key bar, Terminal, Changes, Pin, Hide Pane, Open in New Window and the rest) are disabled, and the sidebar's commands still act on the main window. A Claude, Codex or pi row's title is its first prompt; an OpenCode row's is the title OpenCode gave the session.

The selection survives relaunch. Keyboard: ⌘1…⌘9 select the first nine panes in the "Needs You" group (also listed by label in the Pane menu) and never send or answer anything, ⌘↑/⌘↓ move through the sidebar, ⌘K opens a quick switcher that jumps to any pane by name, workspace, tab or agent, ⌘L focuses the composer, ⌘T toggles Conversation/Terminal, ⌘F searches the conversation.

## Conversation view

A vertically scrolling transcript of the pane's session log, oldest at the top, pinned to the bottom while new content arrives unless the user has scrolled up (then a "Jump to latest" button appears with a count of new messages).

- **User turns**: the user's prompt text, right-aligned or visually distinct, markdown rendered.
- **Assistant text**: rendered markdown (headings, lists, tables, code blocks, inline code, links; syntax highlighting in code blocks is not built yet). Text is selectable and copyable across a message.
- **Tool calls**: one compact row per call, `ToolName` plus a one-line summary of the input (the command for Bash, the path for Read/Edit/Write, the pattern for Grep, the description for Agent). Clicking expands the full input and the paired result. Edits show a unified diff. Long results are truncated with "Show all". Consecutive tool calls with no text between them group under one "N tool calls" disclosure.
- **Summaries and notes** (compaction summaries, system notes such as background task completions): a muted, full-width row.
- **Timestamps** on hover, and a divider when more than 15 minutes pass between turns.
- Thinking blocks are not shown (Claude's logs store them empty).
- Subagent (sidechain) traffic is hidden.
- **Current plan**: when the session has a plan (Claude's latest `TodoWrite` call), a compact checklist sits above the transcript under a "Plan · 2 of 4 done" disclosure: pending items as open circles, the item in progress in the accent colour with its present-tense wording, completed items struck through. More than six items scroll inside the panel. A session without a plan, or whose latest plan is empty or malformed, shows nothing.

Older history loads when the user scrolls near the top. Find (⌘F, Edit › Find) opens a bar above the conversation: it counts the loaded messages holding the text ("2 of 5", ignoring case and accents; tool results stay folded and are not searched), highlights each occurrence, outlines the current message and scrolls to it. Return or ⌘G goes to the next, Shift-Return or ⇧⌘G to the previous, Esc or Done closes the bar. The newest match is current first. A collapsed message that matches shows whole while the bar is open. When older messages exist, the bar offers Load Earlier Messages so the search covers them.

The first version reads the conversation from the session log only. A later version merges the live Herdr screen into this same view for the newest, still-streaming part, rather than adding a separate view for it (the Terminal view below stays for what the log cannot show).

## Terminal view

A read-only rendering of the pane's recent screen text with ANSI colours, in a terminal view sized to the pane's columns. It exists for what the conversation cannot show: spinners, TUI menus, errors printed outside the log, and agents without a parser. It scrolls locally. Clicking it does not send keystrokes; the key bar in the composer does. As built: the terminal is as many columns wide as the pane in Herdr (its tab's layout), scrolls sideways when the window is narrower and fills it when wider, never wraps, and keeps an 8 pt margin around the text; a new read waits while the user has scrolled up; a failed read keeps the last screen with a notice; the text size follows View ▸ Bigger and Smaller.

## Composer

A multi-line text field at the bottom of the detail area, always local. Return sends, Option-Return inserts a newline; with Settings › Send with ⌘Return, Return inserts a newline instead. ⌘Return sends from anywhere in the window either way. A key bar above it sends single keys to the pane: Esc, Ctrl-C, Tab, Shift-Tab, ↑, ↓, Enter; Pane ▸ Send Key has the same keys. While the agent shows a dialog only Esc and Ctrl-C are on, since the others would answer it. While the agent is `working`, sending is still allowed (Claude queues typed input), and the Send button says "Queue". After sending, the text is cleared only once the send command succeeded; on failure it stays with an inline error. Sending is refused while the agent shows a dialog, since typed text would answer it: a `blocked` pane disables sending with a notice, and every send re-reads the screen first ([decisions/0009](decisions/0009-send-guard.md)). Enter follows only once the agent's input box shows the text; if it never does, or the box already held other text, the composer says so and keeps the draft ([decisions/0012](decisions/0012-verified-sends.md)).

Drafts are kept per pane, in memory and on disk, so switching panes or relaunching never loses text. A pane's draft is the same in the main window and in its pane window.

## Blocked panes: prompt cards

When a pane is `blocked`, the agent is showing a dialog (a permission request, an `AskUserQuestion`, a plan approval, a menu). Above the composer, a card shows the question and its options as buttons, parsed from the pane's visible screen ([parsing.md](parsing.md), prompt detection). Choosing an option sends the keystrokes that select it, guarded against the screen having changed since it was parsed. When parsing fails, the card says "This pane is waiting for input" with a button that switches to the Terminal view and the key bar for manual answering. Never guess an answer.

As built in M5 ([decisions/0013](decisions/0013-prompt-cards.md)): the card's heading names the kind (Permission Needed, Question, Plan Ready, Trust This Folder?), then what the prompt is about in monospace (the command or file), the question, and one full-width button per option with its digit, label and explanation; Pane › Answer Prompt lists the same options. Rows answered by typing are left out. While an answer is in flight the buttons are off; a prompt that changed before the answer went, or that is still there after it, is said in the card. The card without options says to answer in the terminal or press Esc, with a Show Terminal button (the key bar's Esc stays on).

## Status and notifications

A macOS notification fires when a pane becomes `blocked`, or goes from `working` to `done`, while the app is not frontmost or that pane is not selected. Clicking it selects the pane. The notification's title is the pane's label, its subtitle the workspace and tab, and its text "Needs input" or "Finished its turn". fabrikater asks for permission the first time it has something to show, and fixture runs never notify. Notifications are on by default and can be turned off per workspace: Turn Off Notifications in a workspace heading's context menu and the Pane menu (for the selected pane's workspace), kept with the other pane notes. The Dock badge shows the number of panes in "Needs You".

**Menu bar item.** A bell in the menu bar, with the number of Needs You panes beside it while any wait (badged bell), struck through while the host is unreachable. Its menu starts with the host and how many panes need you ("arch: 2 panes need you"), lists the Needs You panes as "label · status" in the sidebar group's order, and ends with Open fabrikater. Choosing a pane selects it and brings the main window forward, opening one when all were closed. Settings › Menu Bar › Show Needs You in the menu bar (on by default) hides it; ⌘-dragging it out of the menu bar turns the setting off. After a host switch it shows the new host.

## Connection state

A small indicator in the sidebar footer: connected, reconnecting (with the last error), or offline. When offline, everything already loaded stays readable, and sending is disabled with the reason shown. When nothing has loaded yet, the sidebar says Offline with the reason and does not claim a last known state.

## Settings

Host alias (default `arch`), notification preferences, Return-to-send behaviour, font sizes for conversation and terminal. Settings live in `UserDefaults`.

As built: fabrikater › Settings… (⌘,) is one grouped form, saved as each value changes (`Preferences` behind `PreferencesStorage`, one JSON value under the `preferences` key; fixture runs keep theirs in the fixtures domain).

- Connection: the host alias, with `arch` as the placeholder, and a Connect button. Return in the field or Connect switches to the typed alias at once and keeps it for the next launch: the sidebar reloads from the new host, and the pane and past-session windows of the old one close. Until then the note under the field names the host connected to and the one Return would switch to; text ssh could read as an option is refused and not saved. `FABRIKATER_HOST`, when set, chooses the host at each launch, and the note says that too.
- Composer: Send with Return or ⌘Return, with what the other key does underneath.
- Notifications: when a pane needs input, when an agent finishes its turn, and whether they play a sound. Per-workspace muting stays in the workspace's context menu.
- Menu Bar: whether the Needs You bell is in the menu bar.
- Text Size: the conversation's body text (13 pt by default, the system size) and the terminal's (12 pt), 9 to 24 pt; View › Bigger and Smaller scale both in the front window.

## Visual style

Native macOS: system fonts for prose, the system monospaced font for code and terminal, standard materials and accent colour, full light and dark mode. No custom chrome.
