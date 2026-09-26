# HerdrKit

What Herdr says: the `Herd` model decoded from `herdr api snapshot`, the events channel, the refresh loop that keeps the herd current, and `SendPolicy`. Builds and tests on Linux.

- `Herd` decodes leniently: unknown fields are ignored, missing optional fields are nil, and a record that fails to decode (an invalid pane id) is skipped rather than failing the snapshot.
- Events are pokes, never state (docs/architecture.md, "Events"). `HerdFeed` turns them into coalesced snapshot re-reads, keeps a safety poll, and reconnects the channel with backoff.
- Every mutating command (sends, keys, prompts; M3) goes through `SendPolicy` first.
- Depends on `FabrikaterCore` and `HostKit`. Talks to the host only through a `HostCommandRunner`.
