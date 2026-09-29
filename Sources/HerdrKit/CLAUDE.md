# HerdrKit

What Herdr says: the `Herd` model decoded from `herdr api snapshot`, the events channel, the refresh loop that keeps the herd current, and `SendPolicy`. Builds and tests on Linux.

- `Herd` decodes leniently: unknown fields are ignored, missing optional fields are nil, and a record that fails to decode (an invalid pane id) is skipped rather than failing the snapshot.
- Events are pokes, never state (docs/architecture.md, "Events"). `HerdFeed` turns them into coalesced snapshot re-reads, keeps a safety poll, and reconnects the channel on the shared `ReconnectPolicy`. One reader serves every read request, so snapshot reads never overlap.
- Every change to Herdr is a `HerdrRequest` performed through `HerdrControl`. The composition root wraps the client in `PolicedControl`, so anything that `typesIntoPane` passes `SendPolicy` first; focus does not need to ([decisions/0008](../../docs/decisions/0008-app-drives-live-panes.md)).
- `TerminalReader` reads a pane's recent output for `AppModel`'s `TerminalStore` (the terminal view, [decisions/0013](../../docs/decisions/0013-swiftterm-terminal-view.md)).
- `PaneReader` reads a pane's visible screen; `AppModel`'s `SendGuard` checks it before typing ([decisions/0009](../../docs/decisions/0009-send-guard.md)). A request wrapped in `.checked(ScreenCheck, …)` is sent only if the screen passes the check on the host, in the same command ([decisions/0012](../../docs/decisions/0012-verified-sends.md)); `ScreenCheck.compact` must stay in step with the `awk` in `HostCommand.herdrRequests`.
- Depends on `FabrikaterCore` and `HostKit`. Talks to the host only through a `HostCommandRunner`.
