# Performance at scale

What a long conversation and a large herd cost, where the time went, and what guards it. Measured on the scale fixtures, which `swift scripts/make-scale-fixtures.swift` writes (deterministic, so re-running it rewrites the same bytes):

- `claude-scale.synthetic.jsonl`: a 1.5 MB Claude log, 450 turns and 1,930 messages once read, with markdown, 150 Swift code blocks, tables, tool calls with multi-line results, edits and plans. The 512 KB window the app reads first holds 673 of those messages.
- `claude-scale-more.synthetic.jsonl`: two lines the e2e flow appends to it.
- `snapshot-scale.synthetic.json`: a herd of 8 workspaces, 32 tabs and 64 panes.

## Numbers

A release build on Linux (4 cores), median of 7 runs, before and after the change that added this file:

| What | Before | After |
|---|---|---|
| Live follow: one line appended to a followed 512 KB window | 24 ms | 0.02 ms |
| Reading the 512 KB window (a pane opened, a reload) | 22 ms | 18 ms |
| Reading the whole 1.5 MB log (Load Earlier Messages) | 64 ms | 56 ms |
| Find (⌘F) over 1,930 messages, and its refresh when a line arrives | 7.3 ms | 2.2 ms |
| Highlighting 150 code blocks of 26 lines | 76 ms | 62 ms |
| Markdown blocks of 1,930 messages | 40 ms | 40 ms |
| Decoding the 64-pane herd / building its sidebar | 0.7 ms / 0.1 ms | same |

Before, every appended line parsed the whole window again (every row for the entries, then the plan, facts and changes each scanning the window for their own rows) and diffed every edit again: an agent writing 20 lines a second kept a core busy. The views can only be measured on the Mac (docs/mac-checklist.md, section 2).

## What keeps it fast

- **Each log line is parsed once.** Every format's parser is a `LogReader` (`TranscriptKit/LogReader.swift`) that reads one line onto what it read before. `LogWindow` keeps its reader while the log is followed and reads the whole window again only when it drops its oldest lines, once per 512 KB of growth. For Claude logs `ClaudeLogReader` decodes each line once and hands the row to each feature's `ClaudeRowReader` (entries, plan, facts, changes); an edit becomes diff lines once, when its result arrives. A new feature adds its reader there rather than another pass over the log.
- **Rows on screen that did not change are not drawn again.** `EntryView` is `Equatable` and the conversation wraps it in `.equatable()`, so a new row lays out that row alone rather than re-parsing the markdown and re-highlighting the code of every row on screen. The list is a `LazyVStack`, so rows off screen cost nothing until scrolled to.
- **Find asks only whether a message holds the query** and finds every occurrence only for the highlights of the rows on screen.
- **The highlighter checks ASCII letters by range**, falling back to the Unicode property lookup for other scripts.
- **A herd that changes nothing the sidebar shows leaves `AppStore.sections` alone**, so an idle poll redraws nothing.

## Guards

- `LogReaderTests` (TranscriptKit): following any fixture line by line reads exactly as the whole log read at once, for every format and across a window that drops its oldest lines; and appending 200 lines costs less than one read of the window. That bound is relative, so a slow CI runner slows both sides; before this change the same 200 lines cost 200 reads.
- `AppStoreTests.aHerdThatChangesNothingTheSidebarShowsLeavesItAlone`: re-applying the same herd fires no observation of the sidebar.
- The `scale` e2e flow (docs/e2e.md) opens the long conversation in the 64-pane herd, finds a message far up and follows an appended line, and prints how long each took in the macOS job's log (`scale: … after N s`).

## Not done

- Follow updates are not coalesced: each appended line still hands the main actor a whole transcript. It costs a view diff of the entry ids and the one changed row; dropping updates would change `followTranscript`'s contract that every line is seen, which its tests rely on.
- Markdown and highlighting are not cached across rows scrolled away and back; a 26-line block costs about 0.4 ms, well inside a frame.
