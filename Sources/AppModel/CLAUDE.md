# AppModel

The app's state and behaviour, as `@MainActor @Observable` stores plus the platform-neutral UI values (`AppCommand`, `Keymap`). Builds and tests on Linux; the views in `AppUI` only read these and call `perform(_:)`.

- `AppStore` is the root: it owns the selection, the sidebar rows and the connection state, applies `HerdUpdate`s, and routes every `AppCommand`. `ConversationStore` holds the selected pane's transcript (with `TranscriptCache`), `ComposerStore` the drafts and sending, and `FocusSync` moves Herdr's focus to the selection. Each is one file behind the protocol it needs, so a feature can be removed by deleting its file and its line in `AppStore`.
- `SendGuard` wraps `HerdrControl` and refuses to type while the pane's screen shows a dialog (`PromptKit`'s `Dialog`); the composition root puts it inside `PolicedControl`.
- Stores never build services. Their initializers take protocols (`TranscriptService`, `HerdrControl`) or streams (`AsyncStream<HerdUpdate>`); the composition root in `fabrikater` passes the real ones, tests pass fakes.
- A view never decides, formats or falls back: labels, header text, status words and empty-state messages are store properties, tested here (`.claude/skills/macos-design`, Rule 1).
- Input methods change state synchronously, then start host work in a `Task`. When a read fails, keep the last data and say it is stale.
- A new user action is a new `AppCommand` case with its title, handled in `AppStore.perform(_:)`, and a `Keymap` entry if it has a shortcut.
- Per-pane local state (names, pins, unread marks, and later hidden panes) lives in `PaneNotes` behind `PaneNotesStore`; a feature adds only its own field. Sidebar features are pure functions in `Sidebar+<Feature>.swift`, applied one per line in `AppStore.refreshSections()`.
