# TranscriptKit

Session logs to the normalized transcript model (docs/parsing.md sections 1 to 3). Builds and tests on Linux.

- `Transcript`, `TranscriptEntry` and `TranscriptPart` are the model every view renders. A new agent's parser emits the same model, so views never change for it (docs/structure.md, "Add an agent parser").
- Parsers are pure functions from log bytes to entries: no I/O, tested against fixtures in `Tests/Fixtures/`.
- Features read from the Claude log (`Transcript+Todos.swift`, `+Facts`, `+Changes`) decode rows with `ClaudeLog.row(_:)`, which drops subagent rows, and `Transcript(claudeLog:window:)` assembles the whole model, so a new feature adds its file and one argument there.
- `HostTranscriptService` fetches the log tail through a `HostCommandRunner`: one read of the last 512 KB, then `followClaudeTranscript` follows the log (`LiveFollow.swift`). A service without a follow of its own reads once, through the protocol's default. Hand-over resolution happens on the host, in `HostCommand.claudeLog` (`HostKit`); backfill is M2 work.
- Ported code keeps its Collie attribution header, and THIRD_PARTY_NOTICES.md stays current.
- Depends on `FabrikaterCore` and `HostKit`.
