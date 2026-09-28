# 0010: One conversation store per window

Status: accepted (2026-09-28)

## Context

B15 opens a pane's conversation in a window of its own. Until now `AppStore` owned the only `ConversationStore`, which showed the selected pane, and `AppStore.apply(_:)` re-read that conversation when the selected pane's status changed. A second window needs its own conversation, independent of the selection, and it still needs the herd (the pane's title, status, and the same re-read on a status change), which only `AppStore` holds.

Alternatives considered:

- **The window observes `AppStore` from its view** and forwards pane changes to its own store with `onChange`. That puts the herd-to-conversation wiring in a view, which cannot be tested on Linux.
- **Model-side observation** (`withObservationTracking` in a loop, or `Observations`, which needs macOS 26) to let a window store follow `AppStore`. More machinery than a list of windows, and `Observations` is past the deployment target.
- **A store per window fed by `AppStore`** (chosen).

## Decision

- **`ConversationStore` is per window.** `AppStore.conversation` is the main window's, showing the selection. Each pane window has a `PaneWindowStore` holding its own `ConversationStore`, made by `AppStore.paneWindow(_:)` with the same injected `TranscriptService` and `Clipboard`.
- **`AppStore` feeds every open window from the herd.** It keeps the window stores in a `PaneWindowList`, weakly, so closing a window (its view drops the store) removes it; after each herd or notes change it hands each window its pane and header. A window opened before the first herd (a restored one) waits for it.
- **The conversation owns its own behaviour.** The status-change re-read moved from `AppStore.apply(_:)` into `ConversationStore.show(_:)`, and the conversation-only commands (Reload, Copy Message, Copy Conversation, Show All, Show Less) into `ConversationStore.perform(_:clipboard:)` and `isEnabled(_:)`, which `AppStore` and `PaneWindowStore` both route to.
- **The window is SwiftUI's.** `WindowGroup(for: PaneID.self)` in the composition root; the sidebar's context menu and the Pane menu call `openWindow(value:)` with `AppStore.windowPane(_:)`. `AppCommand.openInNewWindow` exists for its title and whether it applies; opening a window is the view's job, so `perform` does nothing with it.

## Consequences

- Removing the feature deletes `PaneWindowStore.swift`, `AppUI/PaneWindow/`, the scene, the two menu items, the `AppCommand` case and the three `AppStore` members (`paneWindows`, `paneWindow(_:)`, `refreshPaneWindows()`). The moves into `ConversationStore` stay, since the main window uses them.
- ~~The menu bar still acts on the main window.~~ Superseded once pane windows gained the changes inspector and session facts: each `PaneWindowStore` has its own `PanePanels`, the pane window offers its store as a focused-scene value, and the menu bar builds a `MenuTarget` from it, which sends the commands about a pane to the front pane window (or names its pane) and the sidebar's commands to `AppStore`. Both windows draw the pane with one `PaneDetail` view over the `PaneDetailModel` protocol that `AppStore` and `PaneWindowStore` share.
- Each pane window has its own `ComposerStore` too, in its `PaneWindowStore`, so its drafts and sends are separate from the main window's. The composer's send button carries ⌘Return itself, so the key sends the front window's draft rather than the Pane menu's (the main window's).
- Several windows on one pane each read the log; SwiftUI brings an already open window for the same pane to the front instead of opening another.
