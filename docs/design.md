# Design

This document says what the app looks like and how it behaves. [architecture.md](architecture.md) says where the data comes from; [parsing.md](parsing.md) says how raw logs and screens become the models used here.

## The problem it solves

The user runs dozens of agent sessions in Herdr on a host about 140 ms away. Working in them through a remote terminal means every scroll step and every keystroke waits on the network, and long sessions are painful to read. Herdr's workspace and tab organisation is valuable and must be kept. fabrikater shows the same organisation in a native window, renders each conversation locally, and lets the user reply without a remote terminal in the loop.

Non-goals: starting, closing or renaming panes, tabs and workspaces (Herdr's own UI does that; a later milestone may add it); editing files (VS Code does that); running on iOS; any server component on the host; replacing Herdr's TUI for the user's other work.

## Window

One main window, a standard macOS three-part `NavigationSplitView`:

1. **Sidebar: the herd.** Workspaces as sections in Herdr's order (by `number`), each listing its tabs, and under each tab its panes. Each row shows a status dot (`working` animated, `blocked` in an attention colour, `done` as unseen, `idle` quiet), the agent kind icon, and the pane label (`terminal_title_stripped`, falling back to the tab label, then the pane id). A tab with a single pane collapses to one row. Shell panes without an agent are shown dimmed and are selectable (terminal view only). A filter field at the top matches labels. A "Needs you" group pinned at the top lists every `blocked` pane and every `done` pane not yet opened in the app.
2. **Detail: the selected pane.** A header with the pane label, workspace and tab, agent kind, status, and a segmented control **Conversation | Terminal**. Below it, the chosen view, and at the bottom the composer.
3. No third column in the first version.

The arrangement of these panels comes from a layout model in `AppModel`, not from the view hierarchy (`.claude/skills/macos-design`, `references/layout-model.md`). The first version has the fixed shape above; a later milestone makes panels movable and dockable, IDE-style (Xcode, Zed), without rewriting the views.

The selection survives relaunch. Keyboard: ⌘1…⌘9 jump to the first nine panes in the "Needs you" group, ⌘↑/⌘↓ move through the sidebar, ⌘K opens a quick switcher that jumps to any pane by name, workspace, tab or agent, ⌘L focuses the composer, ⌘T toggles Conversation/Terminal, ⌘F searches the conversation.

## Conversation view

A vertically scrolling transcript of the pane's session log, oldest at the top, pinned to the bottom while new content arrives unless the user has scrolled up (then a "Jump to latest" button appears with a count of new messages).

- **User turns**: the user's prompt text, right-aligned or visually distinct, markdown rendered.
- **Assistant text**: rendered markdown (headings, lists, tables, code blocks with syntax highlighting, inline code, links). Text is selectable and copyable across a message.
- **Tool calls**: one compact row per call, `ToolName` plus a one-line summary of the input (the command for Bash, the path for Read/Edit/Write, the pattern for Grep, the description for Agent). Clicking expands the full input and the paired result. Edits show a unified diff. Long results are truncated with "Show all". Consecutive tool calls with no text between them group under one "N tool calls" disclosure.
- **Summaries and notes** (compaction summaries, system notes such as background task completions): a muted, full-width row.
- **Timestamps** on hover, and a divider when more than 15 minutes pass between turns.
- Thinking blocks are not shown (Claude's logs store them empty).
- Subagent (sidechain) traffic is hidden.

Older history loads when the user scrolls near the top. Search (⌘F) matches across loaded messages and offers to load everything for a full search.

The first version reads the conversation from the session log only. A later version merges the live Herdr screen into this same view for the newest, still-streaming part, rather than adding a separate view for it (the Terminal view below stays for what the log cannot show).

## Terminal view

A read-only rendering of the pane's recent screen text with ANSI colours, in a terminal view sized to the pane's columns. It exists for what the conversation cannot show: spinners, TUI menus, errors printed outside the log, and agents without a parser. It scrolls locally. Clicking it does not send keystrokes; the key bar in the composer does.

## Composer

A multi-line text field at the bottom of the detail area, always local. Return sends, Option-Return inserts a newline (Shift-Return and making it configurable wait for the Settings scene). ⌘Return sends from anywhere in the window. A key bar above it sends single keys to the pane: Esc, Ctrl-C, Tab, Shift-Tab, ↑, ↓, Enter. While the agent is `working`, sending is still allowed (Claude queues typed input), and the Send button says "Queue". After sending, the text is cleared only once the send command succeeded; on failure it stays with an inline error.

Drafts are kept per pane, in memory and on disk, so switching panes never loses text.

## Blocked panes: prompt cards

When a pane is `blocked`, the agent is showing a dialog (a permission request, an `AskUserQuestion`, a plan approval, a menu). Above the composer, a card shows the question and its options as buttons, parsed from the pane's visible screen ([parsing.md](parsing.md), prompt detection). Choosing an option sends the keystrokes that select it, guarded against the screen having changed since it was parsed. When parsing fails, the card says "This pane is waiting for input" with a button that switches to the Terminal view and the key bar for manual answering. Never guess an answer.

## Status and notifications

A macOS notification fires when a pane becomes `blocked`, or goes from `working` to `done`, while the app is not frontmost or that pane is not selected. Clicking it selects the pane. Notifications are on by default and can be turned off per workspace. The Dock badge shows the number of panes in "Needs you".

## Connection state

A small indicator in the sidebar footer: connected, reconnecting (with the last error), or offline. When offline, everything already loaded stays readable, and sending is disabled with the reason shown. When nothing has loaded yet, the sidebar says Offline with the reason and does not claim a last known state.

## Settings

Host alias (default `arch`), notification preferences, Return-to-send behaviour, font sizes for conversation and terminal. Settings live in `UserDefaults`. The Settings scene is not scheduled yet (milestones.md, "Later"); until it lands, the host alias comes from the `FABRIKATER_HOST` environment variable.

## Visual style

Native macOS: system fonts for prose, the system monospaced font for code and terminal, standard materials and accent colour, full light and dark mode. No custom chrome.
