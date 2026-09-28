# Architecture

fabrikater is a native macOS app for watching and driving coding agents that run on a remote Linux host. The agents (mostly Claude Code, also Codex, pi/omp, OpenCode and Grok) run as interactive TUIs inside [Herdr](https://herdr.dev), a terminal multiplexer built for coding agents that organises terminals into workspaces, tabs and panes and recognises the agent running in each pane. The app replaces "SSH in and scroll a remote TUI" with a local window: the conversation is rendered on the Mac from the agent's own session log, typing happens in a local text field, and scrolling never waits on the network.

Nothing runs on the host for fabrikater. The app reaches the host only through `/usr/bin/ssh` to the alias in `FABRIKATER_HOST` (default `arch`), and everything it does there is a plain command: the `herdr` CLI, `socat` onto Herdr's API socket, and `tail`/`dd`/`stat` on session logs. Herdr stays the source of truth for layout and agent state; the agent's session log is the source of truth for the conversation.

Facts below marked **verified** were checked on the host on 2026-09-24 against herdr 0.9.1 (server 0.9.0, API protocol 22).

## Why this shape

The host is far away (about 140 ms round trip at the time of writing, through a Tailscale relay), so anything that redraws a remote screen per keystroke or per scroll step feels slow. Rendering locally from data fetched once removes that. A server process on the host was rejected in favour of plain SSH commands: there is nothing to deploy, update or secure on the host, and SSH already carries authentication. The cost is that parsing lives in Swift on the Mac (see [parsing.md](parsing.md)).

## The four channels

| Channel | Command on the host | Lifetime | Carries |
|---|---|---|---|
| Control | `ssh arch …` one-off commands over a shared master connection | per call | snapshot reads, pane reads, sends, file stats |
| Events | `ssh -T arch socat - UNIX-CONNECT:$HOME/.config/herdr/herdr.sock` | long-lived | Herdr topology and agent-status events |
| Transcript tail | `ssh -T arch tail -c +<offset> -F <session log>` | long-lived, one per open conversation | new bytes appended to the session log |
| Terminal read | `ssh arch herdr pane read <pane> --source recent --format ansi --lines <n>` | polled while the terminal view is visible | the pane's screen text with ANSI colour |

### SSH setup

Spawn `/usr/bin/ssh` by absolute path through `Process`; a GUI app does not inherit a shell `PATH`. Always pass `-o BatchMode=yes` (fail instead of prompting), `-o ControlMaster=auto -o ControlPath=~/.ssh/cm-fabrikater-%C -o ControlPersist=10m` (one TCP and key exchange, then each command costs about one round trip), `-o ServerAliveInterval=15 -o ServerAliveCountMax=3`, and `-o Compression=yes` (the snapshot is 66 KB of JSON and session logs are large). Use `-T` for the long-lived channels. The user's `~/.ssh/config` supplies the host, key and any jump host; do not reimplement any of it. Reconnect every long-lived channel with backoff when its process exits (sleep, network change).

Quoting: arguments travel through the remote shell. Never interpolate user text into the command line. Send user text on the process's stdin and read it remotely with `"$(cat)"` or pipe it, and pass only validated identifiers (pane ids match `^w[0-9A-Za-z]+:p[0-9A-Za-z]+$`, session ids are UUIDs or agent-specific id strings) as arguments.

### Control: snapshot

`herdr api snapshot` (**verified**: works from a non-interactive SSH environment with `PATH=/usr/bin:/bin`, herdr is `/usr/bin/herdr`, answers in about 5 ms on the host, 66 KB for 41 panes) returns `{"id":"cli:api:snapshot","result":{"type":"session_snapshot","snapshot":{version:"0.9.1", protocol:22, focused_workspace_id, focused_tab_id, focused_pane_id, workspaces, tabs, panes, agents, layouts}}}`. Record shapes, **verified** against `Tests/Fixtures/snapshot.json` (herdr 0.9.1; about 20 workspaces, 41 panes and 38 agents in September 2026):

- workspace: `{workspace_id:"w3", label, number:1, active_tab_id:"w3:t13", tab_count, pane_count, agent_status, focused}`
- tab: `{tab_id:"w3:t0", workspace_id, label, number, pane_count, agent_status, focused}`
- pane: `{pane_id:"w3:p15", tab_id, workspace_id, terminal_id:"term_65c3b6136c2991", agent?:"claude", agent_session?, agent_status, cwd, foreground_cwd, revision, scroll:{viewport_rows, offset_from_bottom, max_offset_from_bottom}, terminal_title, terminal_title_stripped, focused}`. A pane with no recognised agent (a plain shell) has no `agent` or `agent_session` key at all, not `null`; every shell pane in the capture has `agent_status` `unknown`.
- agent: one per pane that has `agent`: `{pane_id, tab_id, workspace_id, terminal_id, agent, agent_session?:{agent, kind:"id", source:"herdr:claude", value:"<session id>"}, agent_status, cwd, foreground_cwd, revision, state_change_seq, terminal_title, terminal_title_stripped, focused}`. It is the pane record without `scroll`, plus `state_change_seq`. There is no `name` and no `interactive_ready`. `agent_session` is present when that agent's Herdr integration is installed (every agent in the capture has it), so decode it as optional.
- layout: one per tab: `{workspace_id, tab_id, area:{x, y, width, height}, focused_pane_id, panes:[{pane_id, focused, rect:{x, y, width, height}}], splits, zoomed}` (`splits` was empty in every captured tab). No planned feature uses layouts.

`terminal_id` (`term_` plus hex) names the pane's terminal and is distinct from `pane_id`; nothing in fabrikater needs it yet. Ids are opaque strings (`w3`, `w2Z`, `wT`; tabs `w3:t0`; panes `w6:p4P`): compare them, validate pane ids with the regex above, and parse nothing else out of them.

Local pane notes (display names from B1, pins, unread marks, hidden panes and workspaces and the Show Hidden Panes and Show Shell Panes toggles from B5, and B14's Sort Panes By choice) are keyed by `pane_id` and kept in `UserDefaults` on the Mac, never written to Herdr. Runs with `FABRIKATER_FIXTURES` keep theirs in the separate `sh.bayram.fabrikater.fixtures` domain. **Unverified**: whether a pane keeps its id across a Herdr server restart. If it does not, a name stays attached to the old id and is simply unused. Manual check on the Mac: rename a pane, restart the Herdr server from the user's own terminal, and see whether the name comes back.

`agent_status` is one of `idle`, `working`, `blocked`, `done`, `unknown`. `idle` and `done` both mean ready for input; `done` means finished and not yet seen. `blocked` means Herdr recognised an approval or question dialog. `agent_session.value` is the key to the conversation: for Claude it is the session UUID and names `~/.claude/projects/<mangled cwd>/<uuid>.jsonl` (resolution rules in [parsing.md](parsing.md)). `terminal_title_stripped` is the best short label for a pane (Claude sets it to the conversation title).

Decode the snapshot leniently: unknown fields are ignored, missing optional fields are nil. Herdr adds fields between releases.

### Control: requests

Changes go through Herdr's API socket rather than the CLI (`HostCommand.herdrRequests`): the app writes one JSON request per line on the ssh command's stdin, and the remote script sends each line on its own connection, `printf '%s\n' "$l" | socat -t 5 - UNIX-CONNECT:"$HOME/.config/herdr/herdr.sock"`, with a 0.3 s settle between requests, printing one reply line each. A reply with an `error` object is a refusal (`{"error":{"code":"pane_not_found","message":…}}`). The methods the app uses, from Collie's live probes (`HERDR_API.md`, `bridge/mux/herdr/client.ts` at the pinned commit), not yet re-verified on this host:

- `pane.focus {pane_id}`: brings the pane to the front of Herdr's screen; its tab and workspace follow.
- `pane.send_text {pane_id, text}`: types raw bytes, unsubmitted, with no bracketed paste, so a `\n` is an Enter keypress.
- `pane.send_keys {pane_id, keys}`: key names such as `Enter`, `Escape`, `ctrl+c` (Collie's key grammar; `PageUp`, `Home`, `End` and `Delete` are refused).

`HerdrRequest` builds these lines with `JSONSerialization`, so user text is escaped JSON on stdin and never reaches a command line.

### Events

Herdr's API is newline-delimited JSON over a Unix socket at `~/.config/herdr/herdr.sock` (**verified**). Each connection carries exactly one request and one reply, then the server closes it (**verified**: a second request on the same connection gets a connection reset), except `events.subscribe`, which acknowledges and then streams events on the same connection for as long as it stays open (**verified**).

Open the events channel with `ssh -T arch socat - UNIX-CONNECT:'$HOME/.config/herdr/herdr.sock'` (**verified**: `/usr/bin/socat` exists on the host), write one line, and read lines:

```json
{"id":"sub1","method":"events.subscribe","params":{"subscriptions":[{"type":"workspace.created"},{"type":"workspace.updated"},{"type":"workspace.renamed"},{"type":"workspace.closed"},{"type":"tab.created"},{"type":"tab.closed"},{"type":"tab.renamed"},{"type":"pane.created"},{"type":"pane.closed"},{"type":"pane.moved"},{"type":"pane.exited"},{"type":"pane.agent_detected"},{"type":"pane.agent_status_changed","pane_id":"w3:pQ"}]}}
```

The first line back is `{"id":"sub1","result":{"type":"subscription_started"}}`; an error line instead means the subscription was refused. Subscription names are dotted; the stream spells events in snake_case (`pane_created`). `pane.agent_status_changed` must be subscribed per pane, so resubscribe (close and reopen the channel) when the set of agent panes changes. Valid subscription types on protocol 22 (**verified** from the server's error message): `workspace.created`, `workspace.updated`, `workspace.metadata_updated`, `workspace.renamed`, `workspace.moved`, `workspace.reordered`, `workspace.closed`, `workspace.focused`, `worktree.created`, `worktree.opened`, `worktree.removed`, `tab.created`, `tab.closed`, `tab.focused`, `tab.renamed`, `tab.moved`, `pane.created`, `pane.closed`, `pane.updated`, `pane.focused`, `pane.moved`, `pane.exited`, `pane.agent_detected`, `pane.output_matched`, `pane.agent_status_changed`, `pane.scroll_changed`, `layout.updated`. There is no general "pane output changed" subscription.

Treat every event as a poke, never as state: on any event, re-read the snapshot (debounced by about 250 ms). Keep a slow safety poll of the snapshot (every 15 to 30 s) in case the stream silently stalls. This is the model Collie uses and it avoids a resync protocol.

What the app does since M1 (`HerdrClient` and `HerdFeed` in `HerdrKit`): one fixed subscription of the workspace, tab and pane topology events plus `pane.updated` and `pane.agent_detected`, no per-pane `pane.agent_status_changed`, so the channel never needs reopening when panes change. Events arriving within 250 ms of the first cause one snapshot read, the safety poll runs every 20 s, and a dropped channel reconnects after 1, 2, 5, 15, then every 30 s. Whether `pane.updated` fires on a status change is not verified yet (milestones.md, M1).

### Transcript tail

Session logs are append-only JSONL. Sizes on the host (**verified**, 377 Claude logs touched in the last 7 days): median 0.9 MB, 95th percentile 3.9 MB, largest 23.6 MB. So never fetch a whole log to show a conversation.

- What M1 does: one command finds the log and reads its tail, `f=$(ls -1t ~/.claude/projects/*/'<uuid>.jsonl' 2>/dev/null | head -n 1); [ -n "$f" ] || exit 44; tail -c 524288 "$f"` (`HostCommand.claudeLogTail`), and re-runs it when the pane's status changes while the log is not followed. The steps below are M2's plan, except following, which has landed as described below.
- Opening a conversation: `stat -c %s <path>` for the size, then fetch the last window (start with 512 KB, `tail -c 524288 <path>`), drop the first partial line, parse, render. Fetch older windows with `dd if=<path> bs=65536 skip=… count=…` (or `tail -c +<start> | head -c <len>`) when the user scrolls to the top.
- Following: `ssh -T arch tail -c +<size+1> -F <path>` streams appended bytes. Buffer until a newline; a line without its newline is still being written.
- What the app does since the live follow (`LiveFollow.swift` in `TranscriptKit`): after the 512 KB read, `HostCommand.claudeLogFollow` runs `exec tail -c 65536 -F "$f"` on the same log. Starting 64 KB before the end, rather than at a byte offset, needs no `stat` and loses nothing written between the read and the follow; its first (clipped) line is dropped and lines already read are skipped by content (every row has a unique `uuid`). Each new line re-parses the window, which drops its oldest bytes past 1 MB. A dropped follow reads and follows again after 1, 2, 5, 15, then every 30 s. `ReplayRunner` follows a fixture file by polling it, so `FABRIKATER_FIXTURES` runs and the e2e flows can append to a log.
- The log can be replaced: Claude copies a thread into a new session id when it is moved to the background, and the snapshot then reports a new `agent_session.value` for the pane. When the pane's session id changes, close the tail and open the new log.

### Terminal read

For the terminal view, poll `herdr pane read <pane> --source recent --format ansi --lines 400` (**verified**: plain text on stdout, not JSON, about 9 KB for 400 lines) every 1 to 1.5 s while the view is visible, and not at all otherwise. `--source visible` gives only the current screen, which is what prompt detection needs. Do not use the snapshot's pane `revision` to skip reads: it stayed at 17 across 6 s on a `working` pane whose screen was changing (**verified**), so it does not track output.

### Sending

User text reaches an agent as keystrokes into its pane. The primitives are `herdr pane send-text <pane> <text>`, `herdr pane send-keys <pane> <key>…` (for example `enter`, `escape`, `ctrl+c`, arrows), and `herdr agent prompt <pane> <text>`, which pastes and presses Enter in one step. Known trap (**verified** on herdr 0.9.0 in August 2026): `herdr agent prompt` with multi-line text leaves it pasted but unsubmitted in Claude Code's input box; follow it with `herdr agent send-keys <pane> enter`. Success responses from these commands do not prove the agent started a turn; the snapshot's `agent_status` moving to `working` does. `pane send-text` writes raw bytes without bracketed paste, so a newline in the text is a real Enter keypress; `agent prompt` uses the pane's bracketed-paste mode instead. Which of the two submits multi-line text correctly in Claude Code on the current herdr is not settled, so M3 in [milestones.md](milestones.md) tests both before choosing. Collie's exact send sequence (send text, verify it landed in the input box, then Enter) and its race guard (refuse to send if the screen changed since the user looked) are in [parsing.md](parsing.md) section 4.4 and should be followed. The app reads `herdr pane read <pane> --source visible --format ansi` before the text and again before Enter, and refuses while a dialog shows ([decisions/0009](decisions/0009-send-guard.md)); the draft verification is still to come.

Pass the text on stdin, never on the command line: `ssh arch 'herdr pane send-text w3:pQ "$(cat)"' <<< "$text"` (note `$(cat)` drops trailing newlines, which is the desired behaviour for a prompt).

What the app does since [decisions/0008](decisions/0008-app-drives-live-panes.md): the composer sends `pane.send_text` with the trimmed text, then `pane.send_keys ["Enter"]`, through "Control: requests" above. Multi-line text is wrapped in bracketed-paste markers (`ESC[200~` … `ESC[201~`) so its newlines do not submit early; whether Claude Code then submits it on Enter is on the M3 manual check. Collie's draft verification and race guard are not ported yet (M3).

## Safety

The app types into live agents that can run commands with the user's full privileges. Two rules follow. The app sends only in response to an explicit user action (Send, a key button, a prompt-card choice), never automatically. It also moves Herdr's focus to the pane the user selects in the app, which types nothing and so needs no allowlist ([decisions/0008](decisions/0008-app-drives-live-panes.md)). During development and testing, send only into a scratch pane created for the purpose (see [../CLAUDE.md](../CLAUDE.md)); every other pane belongs to the user's running work.

### Send allowlist

Every request that types into a pane (send text, send keys, prompt) goes through `SendPolicy` in `HerdrKit`, by way of `PolicedControl`. It reads `FABRIKATER_SEND_ALLOWLIST`, a comma-separated list of workspace labels (`FABRIKATER_SEND_ALLOWLIST=fabrikater-test`):

- Set and non-empty: a send is allowed only into a pane whose workspace label is on the list. Entries are trimmed of surrounding whitespace, and empty entries are ignored.
- Set but empty (`FABRIKATER_SEND_ALLOWLIST=`): every send is refused.
- Unset: debug builds behave as if it were `fabrikater-test`; release builds have no limit.

Labels can be renamed, so when a list applies, `SendPolicy` looks the pane's workspace label up in a snapshot read at send time, not in the cached herd. If that read fails, or the pane or its workspace is missing from it, the send is refused.
