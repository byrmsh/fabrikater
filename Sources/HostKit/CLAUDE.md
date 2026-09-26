# HostKit

Everything that reaches the host: the typed `HostCommand`s, the ssh argument builder, and the two `HostCommandRunner`s. Builds and tests on Linux.

- A new host command is a new `HostCommand` case (docs/structure.md, "Add a host command"): its remote script, its timeout and its replay fixture name all live in `HostCommand.swift`, next to each other.
- Arguments are validated types (`PaneID`, `SessionID`, `HostAlias`), never a bare `String` from the UI. Anything interpolated into a remote script is single-quoted with `shellQuoted`. User text travels on stdin only.
- `SSHRunner` runs `/usr/bin/ssh` through `Process` with the options in docs/architecture.md, "SSH setup". `ReplayRunner` serves files from a fixture directory, for tests and `FABRIKATER_FIXTURES`.
- Every one-off command has a timeout and throws `HostError`.
- Depends only on `FabrikaterCore`. Knows nothing about what Herdr's output means: decoding lives in `HerdrKit` and `TranscriptKit`.
