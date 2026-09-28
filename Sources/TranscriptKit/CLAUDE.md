# TranscriptKit

Session logs to the normalized transcript model (docs/parsing.md sections 1 to 3). Builds and tests on Linux.

- `Transcript`, `TranscriptEntry` and `TranscriptPart` are the model every view renders. A new agent's parser emits the same model, so views never change for it (docs/structure.md, "Add an agent parser").
- Parsers are pure functions from log bytes to entries: no I/O, tested against fixtures in `Tests/Fixtures/`.
- Features read from the Claude log (`Transcript+Todos.swift`, `+Facts`, `+Changes`) decode rows with `ClaudeLog.row(_:)`, which drops subagent rows, and `Transcript(claudeLog:window:)` assembles the whole model, so a new feature adds its file and one argument there.
- Each agent's log format is a `SessionLog.Format` (`FabrikaterCore`) with its own parser: `ClaudeTranscriptParser`, `CodexTranscriptParser`, `PiTranscriptParser` (pi and omp), `OpenCodeTranscriptParser` (JSON lines SQLite prints from OpenCode's database). `Transcript(_:data:window:)` picks it. Parsers share `JSONLines` (rows, and stable ids for rows without one), `TranscriptBuilder` (folding results onto calls) and `TextRules`.
- `HostTranscriptService` fetches the log tail through a `HostCommandRunner`: one read of the last 512 KB, then `followTranscript` follows the log (`LiveFollow.swift`). A service without a follow of its own reads once, through the protocol's default. Hand-over resolution happens on the host, in `HostCommand.claudeLog` (`HostKit`, `HostCommand+SessionLogs.swift`, which also finds Codex and pi logs); backfill re-reads a larger window (`TranscriptWindow.earlier(than:)`), which `ConversationStore` asks for on Load Earlier Messages.
- `PastSession.swift` lists the sessions a pane's agent kept for its working directory (`SessionHistory`, which `HostTranscriptService` implements with `HostCommand.sessions`) and reads each one's first prompt, from a whole row or one the listing cut. `ListedSessions.swift` holds what differs per agent: the session id in a listed name and where a row keeps the prompt; an agent is one case there and one listing in `HostKit/HostCommand+PastSessions.swift`.
- Ported code keeps its Collie attribution header, and THIRD_PARTY_NOTICES.md stays current.
- Depends on `FabrikaterCore` and `HostKit`.
