# Porting Collie's transcript and dialog parsing to fabrikater

## 0. Scope, sources and how to read this

fabrikater is a native macOS SwiftUI app. It reaches one Linux host (`ssh arch`) and nothing else: no server process runs there. On that host coding agents run as interactive TUIs inside Herdr panes (Herdr is a terminal multiplexer built for coding agents, with a Unix-socket JSON API and a `herdr` CLI over it). The app needs two things Collie already solves: (a) render each agent's conversation from the agent's own on-disk session log, and (b) recognise blocking dialogs on the pane's screen (permission prompts, questions, plan approvals) and answer them with keystrokes. This document specifies both well enough to port, and names the Collie files to translate.

Reference: Collie (MIT, upstream `github.com/AltanS/collie`), pinned at commit `b7ddc17a25af76e87cd9b437053bf51821371055` (2026-09-24, "Merge pull request #284 from AltanS/packaging/1.13.1"). Every citation below is `path:lines` at that commit; prefix `https://github.com/AltanS/collie/blob/b7ddc17a25af76e87cd9b437053bf51821371055/` to open it.

Collie is split in two, and the split matters for the port. The bridge (Bun/TypeScript, `bridge/`) runs on the host, reads session logs and talks to the Herdr socket. The web client (React, `web/src/lib/`) parses screen text into dialog blocks and runs the keystroke choreography. fabrikater collapses both into the Mac app, with every host read or write becoming an SSH command.

Verified live on the host on 2026-09-24: herdr CLI 0.9.1 against a 0.9.0 server (protocol 22), Claude Code 2.1.280, codex-cli 0.156.0, omp 18.2.9, pi 0.87.1, OpenCode 1.18.32, grok 1.0.34. Items marked **UNVERIFIED** were not checked against a live system.

## 1. Finding the session log

### 1.1 The session reference

`herdr api snapshot` prints `{"id":…,"result":{"type":"session_snapshot","snapshot":{version,protocol,workspaces[],tabs[],panes[],agents[],layouts[],focused_*}}}`. Each `agents[]` entry is a pane record carrying `agent` (e.g. `"claude"`) and, when that harness's Herdr integration is installed, `agent_session: {source:"herdr:<agent>", agent:"<agent>", kind:"id"|"path", value}`. Live on this host: 41 Claude panes with `kind:"id"` UUIDs, one OpenCode pane with `kind:"id"` value `ses_…`.

Two rules from Collie that the app must copy:

- Herdr keeps the last session any harness announced for a pane, so a pane relaunched as a different agent still carries the old ref. Accept the ref only when `agent_session.agent` is absent or equals the pane's `agent` (`bridge/mux/herdr/adapter.ts:566-577`; `bridge/mux/herdr/client.ts:178-184` validates `kind` and non-empty `value`).
- `omp` is an alias of the `pi` journal adapter (`bridge/journal/registry.ts:76`). Adapter lookup is by exact agent string, never by prefix.

Every `id` value is regex-checked before it touches a path: Claude, Codex, pi and Grok ids must match `^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$` (case-insensitive), OpenCode ids `^ses_[A-Za-z0-9]{8,64}$`. On the Mac this matters twice over, because the value ends up interpolated into a remote shell command: validate, then single-quote.

### 1.2 Roots and file layout per agent

Roots are resolved in `bridge/config.ts:494-535`. Each harness's own home variable wins; a Collie override takes a comma-separated list.

| Agent | Root (default) | File for a session | Resolution in Collie |
|---|---|---|---|
| claude | `~/.claude/projects` (one per `CLAUDE_CONFIG_DIR` profile) | `<root>/<mangled-cwd>/<uuid>.jsonl` | scan every project dir for `<uuid>.jsonl`, then follow hand-overs (§1.3) — `bridge/journal/claude.ts:333-531` |
| codex | `$CODEX_HOME/sessions` or `~/.codex/sessions` | `<root>/YYYY/MM/DD/rollout-<ISO-ts>-<uuid>.jsonl` | walk year/month/day directories newest-first, match `rollout-*` ending `-<uuid>.jsonl` — `bridge/journal/codex.ts:261-318` |
| pi / omp | `$PI_CODING_AGENT_DIR/sessions`, else both `~/.omp/agent/sessions` and `~/.pi/agent/sessions` | `<root>/<cwd-dir>/<ISO-ts>_<uuid>.jsonl` | `kind:"path"`: must end `.jsonl` and realpath inside a root; `kind:"id"`: scan cwd dirs for a name ending `_<uuid>.jsonl` — `bridge/journal/pi.ts:252-315` |
| opencode | `$XDG_DATA_HOME/opencode` or `~/.local/share/opencode` | one SQLite database `<root>/opencode.db` (WAL) holding every session | check the session id exists in `session` (V1) or `session_v2` (V2) — `bridge/journal/opencode.ts:1-66, 537-591` |
| grok | `$GROK_HOME/sessions` or `~/.grok/sessions` | `<root>/<urlencoded-cwd>/<uuid>/chat_history.jsonl` | scan cwd dirs for `<uuid>/chat_history.jsonl` — `bridge/journal/grok.ts:234-289` |

Host observations. pi names cwd dirs `--home-user--`, omp names them relative to home (`-Projects-app`); Collie never derives these names, it scans, so both work. Codex filenames now carry UUIDv7 ids (`01a0d30e-…`), which the regex accepts. OpenCode is SQLite, not JSON files: this host's database has V1 tables (`session`, `message`, `part`) plus an empty `session_message` and no `session_v2`, so Collie would read it as V1 (the live pane's session has 334 messages and 1268 parts there). Whether omp reports `kind:"path"` through Herdr was not observable (no omp pane was running): **UNVERIFIED**.

**Claude cwd mangling.** Claude Code names the project dir by replacing every non-alphanumeric character of the absolute cwd with `-`: `/home/user/Projects/app` → `-home-user-Projects-app`, `/home/user/work/.scratch` → `-home-user-work--scratch` (the host shows both shapes). Collie deliberately does not use this rule (`bridge/journal/claude.ts:316-323`): it is lossy, and the pane's reported cwd drifts into subdirectories while the session file stays under the launch cwd. Port the scan instead; use the mangled name only as a first guess. Whether Claude Code truncates or hashes very long cwd names is **UNVERIFIED**, one more reason to scan. The scan must stay one level deep: Claude now writes subagent transcripts to `<project>/<uuid>/subagents/agent-*.jsonl` beside the main log (seen on the host), and those are not the pane's conversation.

Over SSH the Claude lookup is one command: `ssh arch "ls -1 ~/.claude/projects/*/'<uuid>.jsonl' 2>/dev/null"`.

### 1.3 Claude: the conversation moves to a new file

Claude Code does not keep one file per conversation. Resuming, `/fork`, and promotion to a background job copy the whole thread into a fresh `<new-uuid>.jsonl` and carry on there, while Herdr may keep reporting the old id. Collie runs two follow steps on every resolve, never cached, because the move happens while the app is running (`bridge/journal/claude.ts:244-526`):

1. Hand-over record (`handedOverTo`, `:294-314`; `followHandOver`, `:415-429`). Read the last 64 KiB of the log (`:279`) and walk its lines newest-first. A non-sidechain `assistant` row met first means the log is live, so stop. A row `{"type":"continued-in","continuedInSessionId":"<uuid>"}` means the conversation moved: look for `<uuid>.jsonl` beside the current file, then anywhere in the same root (`locate`, `:454-461`). Follow at most 8 hops (`:273`), stop on a cycle or a missing target. Cache each file's answer by size and mtime.
2. Conversation root (`conversationRoot`, `:257-270`; `followContinuation`, `:484-526`). The first row carrying a `uuid` is the conversation's root, and every copy keeps it. Among the other `*.jsonl` siblings in the same directory, choose one whose first 64 KiB have the same root uuid, whose mtime is newer than the current best, whose size is at least the current file's, and whose own tail holds no hand-over record. Take the newest such file. Known limit: a `/fork` shares the root, so a more recently written fork wins.

No `continued-in` rows exist in the 60 most recent logs on this host, so step 1 is **UNVERIFIED** here; the root heuristic has to carry the load.

## 2. The normalized transcript model

From `bridge/journal/types.ts:23-82`:

```
TranscriptEntry { uuid: String; ts: String /* ISO or "" */; role: user|assistant|summary|note; parts: [TranscriptPart] }
TranscriptPart =
  text     { text; truncated? }
  thinking { text; truncated? }
  image    { url; mimeType? }
  tool     { name; summary /* one line */; result?: { text; truncated?; isError?; imageUrl? } }
TranscriptPage { entries /* oldest-first */; hasMore; total; fileTruncated }
```

`summary` is a compaction summary the agent wrote about its own history. `note` is machine-injected content that still belongs on screen (a background task finishing, a local command's output). Both render set apart from speech. `uuid` is the paging cursor and must be stable across reads of the same log.

Shared text rules (`bridge/journal/text.ts`):

- Strip ANSI escapes from every text and result (`:23`, regex `ESC\[[0-9;?]*[ -/]*[@-~]|ESC[@-Z\\-_]`).
- Clamp text and thinking parts to 20,000 characters and tool results to 2,000 (`:8-11`), setting `truncated:true` when cut (`clamp`, `:34-37`). Counts are UTF-16 code units, so a Swift port measuring `String.count` (grapheme clusters) will cut in slightly different places.
- Tool summary (`summarizeToolInput`, `:53-92`): from the input object take the first non-empty string among `file_path, command, pattern, query, url, path, description, task, prompt`, in that order (an array value is space-joined); otherwise the first non-empty string value. Collapse whitespace and cap at 200 characters with `…` (`oneLine`, `:40-43`).

Every parser splits on `\n`, skips blank lines, skips lines that fail `JSON.parse` (a partial last write, or the clipped first line of a tail read), and skips lines that parse to a non-object.

### 2.1 Claude (exhaustive) — `parseClaudeTranscript`, `bridge/journal/claude.ts:147-242`

Row envelope: `{type, uuid, parentUuid, timestamp, isSidechain?, isMeta?, isCompactSummary?, message:{role, id, content, …}, …}`.

1. Keep only `type == "user"` or `"assistant"`. Everything else is dropped: on the host that is `attachment` (the most common row type: reminders, environment, skill listings, hook output), `system` (`stop_hook_summary`, `turn_duration`, `away_summary`, `compact_boundary`, `local_command`), `last-prompt`, `mode`, `permission-mode`, `ai-title`, `queue-operation`, `file-history-*`, `pr-link`, `cost-state`, `atis-latch`, `continued-in`.
2. Drop rows with `isSidechain == true` (subagent traffic; now rare in main logs, see §1.2).
3. Skip rows whose `message` is not an object. `uuid` = row `uuid` or `""`; `ts` = row `timestamp` or `""`.
4. If `message.content` is a string, the row is a human turn or injected plumbing. Classify it after stripping ANSI (`classifyUserText`, `:80-106`); an "envelope" means the trimmed-start text begins with `<tag>`:
   - `<system-reminder>`, `<local-command-caveat>`: drop the row.
   - `<command-name>`: role `user`, text `"<command-name inner> <command-args inner>"` trimmed; drop if empty.
   - `<local-command-stdout>`: role `note`, its inner text; drop if empty.
   - `<task-notification>`: role `note`, the inner text of its `<summary>`; drop if absent.
   - anything else: role `user`, the whole text; drop if blank.
5. If `message.content` is an array, for each block:
   - `text` with non-blank `text`: text part.
   - `thinking` with non-blank `thinking`: thinking part. Claude persists most thinking blocks with empty text (185 of 189 in one host log), so these are rare.
   - `tool_use`: tool part `{name (default "tool"), summary: summarizeToolInput(input)}`, remembered in a map `tool_use.id → part`.
   - `tool_result`: flatten `content` (a string, or the `text` of each text block joined with `\n`), strip ANSI. If the map holds `tool_use_id`, set that part's `result = clamp(text, 2000)` plus `isError:true` when `is_error == true`, and remove the map entry. The earlier part is mutated in place, inside an entry already emitted: results fold onto calls without reordering anything. If no call matches (it fell outside a tail window) and the text is non-blank, emit an orphan tool part `{name:"result", summary:"", result}` in this row.
   - Any other block type (`image`, `document`, `tool_reference`) is ignored.
6. Drop the row if it produced no parts. So a user row that is pure tool-result traffic folds away and never renders as a fake "You".
7. Role: `summary` if `isCompactSummary == true`, else `assistant` for assistant rows, else `note` if step 4 said so, else `user`.
8. Order is file order. There is no sort.

Gaps to decide on deliberately, all confirmed against 60 recent host logs:

- **No merging by message id.** Claude writes one API response as several rows, one content block per row, all sharing `message.id` (4,120 of 9,085 assistant rows continue the previous row's id; no row holds more than one block; every row carries the final `stop_reason`). They are finished rows, not streamed partials, and none were duplicates. Collie emits one entry per row. For a chat UI, group consecutive assistant entries with the same `message.id` into one bubble; do not dedupe them.
- **`isMeta` is not filtered.** 147 `isMeta:true` user rows on the host would render as "You": skill bodies ("Base directory for this skill: …"), "Another Claude session sent a …" relays, `[Image: original WxH …]` notes, and slash-command expansions. Recommend dropping `isMeta` rows or rendering them as `note`.
- **Other envelopes pass through as user speech:** `<command-message>`, `<bash-input>`, `<bash-stdout>`, `<pasted_content …>`. Map `<bash-input>` to user and `<bash-stdout>` to note if you want parity with the terminal.
- **No images for Claude.** User `image` blocks (`source.type:"base64"`, `media_type`, `data`) and `tool_result` content images are dropped; only the pi adapter emits image parts. If fabrikater wants them, build a `data:` URL the way pi does (§2.3) and never follow remote URLs.
- Compaction rows (22 on the host) carry `isCompactSummary:true`, and may also carry `isVisibleInTranscriptOnly:true`.

### 2.2 Codex — `bridge/journal/codex.ts:145-246`

Rows are `{timestamp, type, payload}`. Codex writes every turn twice, as `response_item` (API-shaped) and as `event_msg` (UI stream). Keep only `response_item`, since only it carries tool output, and ignore `event_msg`, `session_meta`, `turn_context` and `world_state`. By `payload.type`:

- `message`: roles `user` and `assistant` only (the `developer` role carries injected system prompts: drop it). Text = the `text` fields of the content blocks joined with `\n`. Drop if blank, and drop a user message starting with `<environment_context>` (`:132-134`).
- `reasoning`: join `summary[].text` with a blank line and emit an assistant thinking part; drop encrypted-only rows.
- `function_call`: assistant tool part; `arguments` is a JSON string, so parse it before summarising (fall back to `oneLine` of the raw string); remember `call_id`.
- `function_call_output`: `output` is a JSON string wrapping `{"output":"…"}`, so unwrap it, falling back to the raw string (`:102-115`). Fold onto `call_id`, else emit an orphan.

Rows carry no id, so the cursor is synthesised from a djb2 hash of the line plus an occurrence counter, `cx-<base36>[-n]` (`:73-81`). Any stable scheme works for the Swift port, since the cursor never leaves the app.

### 2.3 pi and omp — `bridge/journal/pi.ts:145-241`

Keep `type == "message"` rows (skipping `session`, `model_change`, `thinking_level_change`, and omp's `custom`, `custom_message`, `title_change`, `ttsr_injection`). `uuid` = row `id`. `message.role` is `user`, `assistant` or `toolResult`. User and assistant content blocks are `text`, `thinking` (real text in pi), `image` (`data` plus `mimeType`) and `toolCall` (`arguments` is an object; remember its `id`). A `toolResult` row folds onto `toolCallId`, taking `isError` and the first renderable image as `result.imageUrl`; an unmatched one becomes an orphan named `toolName`. Image URLs (`resolveImageUrl`, `:93-109`) accept only `blob:sha256:<64hex>` (served by Collie from pi's blob store; fabrikater would fetch the blob over SSH, and its location is **UNVERIFIED**), a `data:image/…` URL, or bare base64 with an `image/*` mimeType. Everything else, `http(s)` above all, is dropped.

### 2.4 OpenCode — `bridge/journal/opencode.ts`

No file per session. Open the database read-only and run exactly these queries with bound parameters. The same file holds OAuth tokens in `account`, `credential` and `control_account`, so never touch those tables.

- Store choice (`:156-169`): the V2 tables (`session_v2`, `session_message`) win when the session is only there; when it is in both stores the newer `max(time_updated)` wins, and a tie goes to V2.
- V1 (`:271-297`): `select id, time_created, data from message where session_id=? order by time_created, id` plus `select id, message_id, data from part where session_id=? order by id`, with parts grouped by `message_id`. The role is `data.role`.
- V2 (`:344-368`): `select id, type, time_created, data from session_message where session_id=? order by seq`. `type` is the role: `user` and `assistant` pass, `compaction` becomes `summary`, everything else is dropped. Parts are `data.content[]`, falling back to `data.text`, then `data.summary`, then `data.error.message`.
- Part mapping (`opencodePart`, `:417-464`): `text` → text; `reasoning` → thinking; `tool` → tool part named `tool` (V1) or `name` (V2), summarised from `state.input`. The result comes from `state.status`: `completed` takes `state.output` (V1) or the joined text of `state.content[]` (V2); `error` takes `state.error` as a string or `.message`, with `isError`; pending or running has no result. `step-start` and `step-finish` are dropped. Timestamps come from `data.time.created` (ms) or the row's `time_created`.
- Change detection (`:194-225`): row count stands in for size and `max(time_updated)` for mtime.

Over SSH: `ssh arch sqlite3 -readonly -json ~/.local/share/opencode/opencode.db "<query>"` (sqlite3 is at `/usr/bin/sqlite3` on the host). The id must pass the `ses_` regex before interpolation, because the sqlite3 CLI cannot bind parameters.

### 2.5 Grok — `bridge/journal/grok.ts:95-226`

`system` rows are dropped. A `user` row is dropped if it has `synthetic_reason`; otherwise the text is the inner of `<user_query>…</user_query>`, or the whole text when the row has a numeric `prompt_index`, else it is dropped. A `reasoning` row's `summary[].text` is held and prepended as a thinking part on the next `assistant` row. An `assistant` row's `content` (string or blocks) becomes a text part, plus one tool part per `tool_calls[]` entry (`arguments` is a JSON string). `backend_tool_call` becomes a tool part named `kind.tool_type`, summarised from `kind.action`. `tool_result` folds onto `tool_call_id`. `ts` is always `""`. The cursor is the row `id`, else a djb2 `gk-…` hash.

## 3. Incremental reading

What Collie does: no incremental parsing at all. `TranscriptStore.page` (`bridge/journal/store.ts:56-95`) stats the file; if size and mtime match the cached entry, it reuses the parsed entry list (an LRU of 4 files, `:11`); otherwise it re-reads the last 32 MiB (`MAX_TRANSCRIPT_BYTES`, `bridge/journal/files.ts:46`; `tailBytes`, `:154-164`) and re-parses the whole thing. Pagination (`pageEntries`, `:28-44`) is newest-anchored: with no cursor it returns the last `limit` entries; with `before=<uuid>` it returns the `limit` entries before that one. An unknown cursor degrades to the newest page, never to an empty one. `hasMore` is true when entries exist before the window, or when the file was clipped and the window starts at the first parsed entry. The route defaults `limit` to 200 and caps it at 5000 (`bridge/server.ts:228-229, 2372-2383`). A partially written last line and a clipped first line are both handled the same way: they fail `JSON.parse` and are skipped.

Recommended client design (not in Collie):

- Keep per-file state `{path, inode, offset, carry, parserState, entries}`. `parserState` must include the pending tool map (and Grok's held thinking), because a `tool_result` row arrives after its call, and folding it mutates an entry the UI already shows. Publish the mutated entry as an update.
- Poll with one SSH round trip: `stat -c '%s %i %Y' "$f"; tail -c +$((OFFSET+1)) "$f" | head -c 4194304`. `tail -c +K` is 1-based, so the byte at 0-based offset `O` is `+O+1`. Work in bytes: split the returned `Data` on `0x0A`, decode each complete line as UTF-8, and hold the bytes after the last newline as `carry` without consuming them. Advance `offset` only past the last newline.
- First open: if the size exceeds the cap, start from `size - cap`, discard up to the first newline, and set `fileTruncated`. Load older history on demand by reading earlier byte ranges (`tail -c +A | head -c B`), which avoids re-reading the whole file the way Collie does.
- Reset and re-parse from zero when the inode changes or the size drops below `offset`. Claude never truncates in practice; this is a guard.
- Re-resolve the file (§1.3) whenever the pane's `agent_session.value` changes in a snapshot, and every so often while the pane is active, because the conversation can move to a sibling file without Herdr noticing. A switch to a new path is a fresh load, not an append.
- For a live pane, `ssh arch tail -c +K -F "$f"` over a persistent connection (ssh `ControlMaster`) is cheaper than polling. It still needs the same carry handling, and it misses a move to a sibling file.
- OpenCode is a database, not a file: poll the change-detection query and re-run the message query on change.

## 4. Dialog detection from screen text

### 4.1 Input

The grammars run on the pane's screen as Herdr returns it from `pane.read` with `source:"recent"` and `format:"ansi"` (`bridge/server.ts:2287-2344`; `bridge/mux/herdr/adapter.ts:299-316`), with `lines` set to 600 (`web/src/lib/loaders.ts:369`, raised up to 1000, which is Herdr's silent clamp, `:370-379`). The text is SGR-only ANSI. The client parses it into `StyledLine { segments: [AnsiSegment{text, fg?, bg?, bold?, dim?, …}] }` (`web/src/lib/ansi.ts`, `web/src/lib/blocks.ts:58-63`), splits on `\n`, and strips `\r` (the CLI emits `\r\n`). The grammars match on segment text joined per line, which matters because `❯` and `1.` are separate styled segments. The wizard also reads `bg` to find the current stepper chip.

Caution from `HERDR_API.md:67-89`: on an idle, recognised agent, a `recent` read in `text` format with `lines` greater than the viewport scrolls the operator's real terminal to harvest pages. `ansi` was never observed to do that, and `visible` cannot. Use `format:"ansi"` for every read, and use `source:"visible"` for background polling. Agents on the alternate screen (Claude) have no scrollback anyway, so `visible` gives the grammars what they need.

### 4.2 Output model — `web/src/lib/blocks.ts:65-170` and `web/src/lib/harness/*-model.ts`

An adapter returns `[Block]`: raw lines above, at most one lifted block at the tail. Every lifted dialog is anchored to the last non-blank line.

| Block kind | Model (key fields) | How a tap becomes keys |
|---|---|---|
| `prompt-select` | `PromptModel{question, options[{label, description?, keys, keyLabel?}], family: select\|permission\|trust\|plan, caption?, feedback?{key, focused, text, purpose?}, signature, coreSignature}` (`prompt-model.ts:15-113`) | send `option.keys`: `select` is `[n,"Enter"]`, the other families are `[n]` alone; a pointer-only trust dialog walks `Up`/`Down` then `Enter` (`pointerWalk`) |
| `wizard` (multi-question AskUserQuestion) | `phase:"question"{steps[{label, answered, current}], question, options[{label, description?, keys:[n], chosen, escape}], signature}` or `phase:"review"{steps, answers[{question, answer}], incomplete, signature}` (`wizard-model.ts:55-69`) | one digit selects and advances; review `1` submits, `2` cancels; `Left`/`Right` move between steps |
| `preview-select` | `{question, options[{label, n, pointed, chosen}], preview[], note{state: none\|editing\|attached, text}, steps?, regionSignature, coreSignature}` | the digit only moves the pointer; poll until the pointer is on that row; then send `Enter` in a separate call (a combined `[n,"Enter"]` picks the wrong row) |
| `multi-select` | `phase:"checkbox"{question, options[{n, label, checked}], escape?, pointer, pointerRow, steps?, advanceLabel, toggle: digit\|pointer, signature, regionSignature}` or `phase:"review"{incomplete, pointer, submit, cancelLabel?, …}` | Claude uses digit mode: digit N toggles option N. Submit is a closed loop: `Down` until it clamps, `Up` once, verify the pointer is on Submit, then `Enter` |
| `menu` (generic modal, e.g. `/model`, `/effort`) | `MenuModel{title, actions[{label, keys, cancel?}], nav{upDown, leftRight?{verb, label, values?}}, signature}` | only keys the footer printed, plus the arrows; never a synthesised digit (ADR 0009) |
| `autocomplete` | `{entries[{name, description}]}` | presentation only, no keys |
| `unread-dialog` | `{key, agent, signature}` | the adapter's declared `cancelKey` (`Escape` for Claude and Codex, `ctrl+c` for Grok) when nothing lifted and the composer is not visible (`harness/index.ts:96-128`) |

### 4.3 Claude detection (`web/src/lib/harness/claude/index.ts:37-154`)

Order: preview-select → wizard → multi-select → prompt-select → effort slider → `/resume` picker → generic menu → autocomplete → raw with the chrome stripped. The first match wins, and the lines above its `startLine` stay raw.

prompt-select (`claude/prompt-select.ts:335-466`), the one to port first:

1. `fi` = the last non-blank line. `classifyFooter(fi)` (`claude/markers.ts:222-231`), case-insensitive: `enter to select` → `select`; `ctrl+g to edit` or a `.claude/plans/` path → `plan`; `tab to amend` → `permission`; `enter to confirm` → `trust`, but only if the screen also shows `is this a project you created or one you trust` or `yes, i trust this folder` (`:186-196`). Anything else declines.
2. Option rows in the 24 lines above the footer match `^(?:❯\s*)?(\d+)\.\s+(.+)$` (`:94`). Keep the trailing run numbered consecutively from 1. With fewer than two rows, only the `trust` family can fall back to the pointer-list shape; with more than nine, decline.
3. The footer may sit at most 3 lines below the last option (plus 4 when a plan feedback hint `shift+tab to approve with this feedback` is present). A `select` footer declines if a stepper line (two or more of `☐☒☑✔✅`) sits within 12 lines above; that screen belongs to the wizard.
4. The question is the nearest line containing `?` within 12 lines above the first option, stopping at a horizontal rule.
5. Description = the non-blank lines between one option and the next, joined. Labels starting `Type something` or `Tell Claude what to change` are free-text rows: in the `plan` family they become `feedback` (focused when the row starts with `❯`), and otherwise they are dropped.
6. `signature` = the raw lines from 40 above the first option through the footer. `coreSignature` = the lines from the question through the footer, with `❯` replaced by a space and the feedback rows collapsed to one token.

The other Claude grammars (file sizes are line counts): `wizard.ts` 322 (stepper chips `([☐☒☑✔✅])\s*([^☐☒☑✔✅←→]*)`, current chip by background colour, a review step with no footer), `multi-select.ts` 360 (`[ ]`/`[✔]` prefixes, an advance row `^❯?\s*(Submit|Next)$`, `ready to submit your answers?`), `preview-select.ts` 289 (footer `n to add notes`), `effort.ts` 351, `resume.ts` 208, `menu.ts` 125 plus the shared `menu-hints.ts` 231, `autocomplete.ts` 191, `chrome.ts` 646 (input box: a bare `─` bottom border, the `❯` prompt row, and a top border that may carry a label; statusline and draft extraction; `composerReady` = `hasInputBox`), `markers.ts` 231, `paste.ts` 178 (`[Pasted text #N +M lines]` counts as evidence of a send). All Claude harness files together: 3,554 lines.

Other adapters (`harness/registry.ts:26-45`, exact agent string): `codex` (825 lines: trust footer `Press enter to continue`, approval footer `Press enter to confirm or esc to cancel` offering only one-shot Yes and No as buttons, question cards `Question i/n (k unanswered)` answered by digit alone), `grok` (964 lines: permission footer `1/N:select … Ctrl+c:cancel`, ask cards with `┃`-prefixed rows and a `z` free-text row, a plan menu of `a:approve`/`q:quit plan` hints), `omp` (chrome and composer only, lifts no dialogs; its replies go in chunks of at most 512 characters and 4 newlines so omp does not collapse them into a chip, `omp/reply-chunks.ts`). pi and opencode have no screen adapter: raw mirror only.

### 4.4 The race guard and answering

Every tap follows the same choreography (`web/src/lib/dialog-guard.ts:80-158`, `web/src/lib/harness/guard.ts:73-157`):

1. Read the pane again, fresh.
2. Compare `revision` with the one the block was detected against (defence in depth only: `pane.read` still returned `revision:0` on the 0.9.0 server, while snapshot pane records carried non-zero values whose meaning is **UNVERIFIED**).
3. Re-run the same adapter's `buildBlocks` on the fresh screen, take the tail block of the same kind, and compare it with the tapped model using the kind's comparator (`harness/dialog-contract.ts:123`): `commits` (e.g. `promptsEqual`: family, question, coreSignature, labels, keys, signature, feedback state) for keys that act, `identity` for arrows and pointer walks. On a mismatch, send nothing and refresh.
4. Send the keys bound to the region: the client passes `expected_prompt` = the model's region text, and the bridge re-reads the pane (`recent`, `ansi`) right before `send_keys`, refusing with `prompt_changed` (HTTP 409) unless `verifyExpectedPrompt` finds the region's lines contiguous, with SGR stripped, trailing spaces trimmed and blank lines dropped, ending within the last 6 non-blank lines (`bridge/prompt-binding.ts:26-55`; `bridge/server.ts:2872-2920`). fabrikater has no bridge on the host, so this second check becomes a read over SSH immediately before the send. It can collapse to a single remote shell snippet (`herdr pane read … ; check ; herdr pane send-keys …`) to keep the gap to two local RPCs.
5. Multi-step flows poll 8 times at 350 ms (`guard.ts:43-44`), with three outcomes: `ok`, `drifted` (a different dialog, or none: stop), `timeout` (still our dialog: a bounded retry is safe).

Free-text replies (`web/src/lib/reply-action.ts:260-403`, `bridge/server.ts:2551-2589`):

1. Pre-flight read: refuse if `composerReady` is false.
2. Optionally clear a stranded draft with `ctrl+k` plus Backspaces.
3. `pane.send_text` the text, unsubmitted.
4. Poll until `extractInputDraft` shows the text (at least 8 visible characters must match), or the paste placeholder is consistent with it.
5. Only then send the submit keys (`COLLIE_SUBMIT_KEYS`, default `["Enter"]`, `bridge/config.ts:586-629`), bound to `composerPrompt`. If the text never appears, send no Enter at all: a focused dialog eats the text and the Enter would answer it (issue #34).

Unknown agents get a one-shot send: text, a 350 ms settle, then Enter. `pane.send_text` writes raw bytes with no bracketed paste, so a `\n` in the text is a real keypress (`HERDR_API.md:95-102`). The app should send multi-line text as one call and never split it.

### 4.5 What will break first when TUIs update

Footer phrases (`classifyFooter`, Codex and Grok footers) and exact option labels (`Yes, proceed`, `No, and tell Codex what to do differently`); the `❯`/`›`/`┃` glyphs and the indent columns; the input-box border shape in `chrome.ts`; the wizard's reliance on background colour for the current chip; the `[Pasted text #N +M lines]` token; the fixed windows (24-line option scan, 3-line footer gap, 12-line question scan); and on the journal side, Claude's `continued-in` record and the Codex double-booking. Mitigation: port Collie's 248 byte-faithful fixtures (`web/src/fixtures/panes/*.txt`, ANSI with `\r\n`) as Swift tests, and fail closed, meaning no block and no keys, whenever a grammar is unsure.

## 5. Herdr interaction

Socket protocol (`HERDR_API.md:9-28`): Unix socket `$HERDR_SOCKET_PATH`, default `~/.config/herdr/herdr.sock`. Newline-delimited JSON `{"id":"<string>","method","params"}`, one request per connection (the server closes after replying), replies `{"id","result":{type,…}}` or `{"error":{code,message}}`, and a request line capped at 1 MiB. The exception is `events.subscribe {subscriptions:[{type, pane_id?}]}`: it keeps the connection open, acks `subscription_started`, then streams `{"event":"<snake_case>","data":{…}}`. The pane-scoped types `pane.agent_status_changed`, `pane.output_matched` and `pane.scroll_changed` require a `pane_id` (`HERDR_API.md:324-375`). Collie polls `session.snapshot` and uses events only to trigger an early re-poll; the snapshot stays authoritative.

| Collie call (`bridge/mux/herdr/client.ts`) | Params | Via CLI? |
|---|---|---|
| `session.snapshot` (`:373`) | `{}` | yes: `herdr api snapshot` (full JSON reply) |
| `pane.read` (`:602-615`) | `{pane_id, source: visible\|recent\|recent_unwrapped\|detection, lines, format: text\|ansi}`; the 0.9 schema also has `strip_ansi` (default true, effect with `ansi` **UNVERIFIED**) | partly: `herdr pane read <id> --source … --lines N --format ansi` prints the bare text with `\r\n`, and no `revision` or `truncated` |
| `pane.send_text` (`:620-623`) | `{pane_id, text}` | yes: `herdr pane send-text <id> <text>` |
| `pane.send_keys` (`:625-627`) | `{pane_id, keys:[…]}`, names like `Enter`, `Escape`, `Up`, `Tab`, `ctrl+c`, `shift+tab`, one-character literals; no `PageUp`/`Home`/`End`/`Delete` (`bridge/mux/herdr/keys.ts:26-84`) | yes: `herdr pane send-keys <id> <key>...` |
| `events.subscribe` (`:384-495`) | as above | no: socket only |
| not used by Collie: `agent.prompt` | `{target, text, wait?}` | `herdr agent prompt <target> <text> [--wait]` |

From the Mac: plain CLI calls work (`ssh arch herdr pane send-keys w3:pQ 1`). For anything that needs `revision`, or for events, pipe raw JSON through socat, which is installed: `ssh arch 'socat -t 2 - UNIX-CONNECT:$HOME/.config/herdr/herdr.sock'` with the request on stdin. That was verified read-only for `pane.read`. For events, hold that SSH session open and read lines. A non-interactive SSH shell may not export `HERDR_SOCKET_PATH`, so use the default path explicitly.

Submitting a reply. Collie uses `send_text` then `send_keys(submitKeys)`, never `agent.prompt`. According to `herdr --skill`, `agent prompt` uses the pane's bracketed-paste mode, sends Enter in the same ordered write, and refuses an agent sitting at an approval dialog with `agent_blocked`. That makes it a simpler first reply path, but it skips the draft verification above. The user's own notes record that `agent prompt` left multi-line text unsubmitted in the past: **UNVERIFIED** on 0.9.1, so probe before relying on it. Answering a dialog always uses `send-keys`.

## 6. Licensing

Collie is MIT (`LICENSE`: "Copyright (c) 2026 Altan Sarisin"). A Swift translation of its parsers and grammars is a derivative work of substantial portions, so fabrikater must ship the full MIT notice, the copyright line plus the permission paragraph, in its source tree (e.g. `THIRD_PARTY_NOTICES` or a header in each ported file) and in the app bundle's acknowledgements. It is good practice to add a comment in each ported Swift file naming its origin, e.g. `// Ported from AltanS/collie@b7ddc17 bridge/journal/claude.ts (MIT)`. The fixtures under `web/src/fixtures/panes` fall under the same licence if copied.

## 7. Port order

1. **Claude journal**: `bridge/journal/text.ts`, `types.ts`, `claude.ts` (parser, `classifyUserText`, resolution, `continued-in` and root following), the `store.ts` paging semantics, and the byte-offset tailer from §3. Add `isMeta` filtering and `message.id` grouping as deliberate deviations. Test against `bridge/journal/claude.test.ts` cases and real host logs.
2. **Herdr access layer**: snapshot polling and session-ref validation, `pane read` (ansi), `send-text` and `send-keys` through the CLI, socat for raw JSON and events.
3. **Claude screen grammars, minimum set**: `lib/ansi.ts`, `blocks.ts`, `claude/markers.ts`, `chrome.ts` (`composerReady`, draft), `prompt-select.ts`, `prompt-model.ts`, the guard (`harness/guard.ts`, `dialog-guard.ts`) and the prompt-binding check. That covers permission, trust, plan and single AskUserQuestion.
4. **Guarded free-text reply** (`reply-action.ts`, `claude/paste.ts`), or `agent prompt` as an interim path after probing it.
5. **Remaining Claude grammars**: wizard, multi-select, preview-select, menu plus effort plus resume, unread-dialog, with the matching `*-action.ts` choreographies.
6. **Codex journal and screen adapter**, then **OpenCode** (sqlite3 over SSH), then **pi/omp** journals (plus omp reply chunking), then **Grok**.
