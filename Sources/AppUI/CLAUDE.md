# AppUI

Thin SwiftUI views over `AppModel` stores. macOS only: cloud sessions cannot compile it, and CI's macOS job does.

- Layout only. Anything worth a test (decisions, formatting, state transitions) goes in a store in `AppModel`.
- One folder per feature (`Sidebar/`, `Conversation/`, `Composer/`, …) and one view per file.
- View-local state is `@ViewState private var` (see `ViewState.swift`). Never write the State wrapper by its SwiftUI name, `#Preview`, `@Previewable` or `@Entry`: `scripts/check.sh` rejects them.
- Never await the host from an input handler. Call the store, which updates state first.
- Review every view against `.claude/skills/swiftui-pro` and the macOS references in `.claude/skills/swiftui-expert-skill`. The repo's rules win over the skills.
- `Terminal/` wraps SwiftTerm's AppKit `TerminalView`, the one UI package (decisions/0013). Only `AppUI` imports it.
- Native macOS look: system fonts, materials and accent colour, light and dark mode (docs/design.md).
