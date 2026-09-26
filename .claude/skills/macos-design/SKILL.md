---
name: macos-design
description: fabrikater's macOS design rules. Use when designing, writing or reviewing any window, pane, sidebar, toolbar, inspector, menu, keyboard shortcut or list in fabrikater, and when adding UI state to AppModel. Covers the model-driven pane layout (IDE-style, movable panes), platform-neutral UI logic, density for a developer tool, and a review checklist.
license: MIT (repo-owned; references/hig-rules.md is adapted from ehmo/platform-design-skills, MIT)
metadata:
  author: fabrikater
  version: "1.0"
---

# macOS design for fabrikater

fabrikater is a developer tool in the family of Xcode, Zed, Tower and Finder: dense, keyboard-first, many panes, one window. This skill says how its UI is laid out and structured. It sits on top of [docs/design.md](../../../docs/design.md) (what each screen shows) and [docs/structure.md](../../../docs/structure.md) (targets and rules) and never contradicts them; if it seems to, the docs win and this skill gets fixed.

Use it together with `swiftui-pro` (review every view) and `swiftui-expert-skill` (`references/macos-scenes.md`, `macos-views.md`, `macos-window-styling.md`, `toolbar-patterns.md`, `focus-patterns.md`, `list-patterns.md`).

## Precedence

The repo's rules win over every example here and in the other skills:

- `@ViewState` instead of `@State`. No `#Preview`, `@Previewable`, `@Entry` or SwiftData. The code builds with the Command Line Tools only, so no asset catalogs, storyboards or anything needing Xcode.
- `@Entry` is banned, so custom `EnvironmentValues`, `FocusedValues` and `ContainerValues` entries are written by hand: a `private struct …Key: EnvironmentKey` (or `FocusedValueKey`) plus a computed property.
- Views are thin. Only `AppUI` and `fabrikater` import SwiftUI or AppKit.

## Rule 1: the UI is a projection of platform-neutral state

A later Android port rewrites only the view layer, by hand or by agents, so everything that is not drawing lives in `AppModel` as plain Swift (Foundation only, builds on Linux, tested there):

- **View models, not domain objects.** A store exposes what a row shows: the label already resolved (`terminal_title_stripped` → tab label → pane id), the status as an enum, counts, whether it is dimmed. A view never decides, formats or falls back.
- **Commands are data.** Every user action is a case of one `AppCommand` enum (`selectPane(PaneID)`, `toggleDetailMode`, `focusComposer`, `send`, `movePanel(PanelID, to: DockEdge)`, …) handled by one `perform(_:)` on the store. Menus, toolbar buttons, context menus, keyboard shortcuts and notifications all dispatch these cases; none contains logic.
- **Shortcuts are data.** One `Keymap` table maps commands to `KeyChord` values (a key and a set of modifiers, defined in `AppModel`, not SwiftUI's `KeyboardShortcut`). `AppUI` translates a chord into `.keyboardShortcut`. A Linux test checks that no two commands share a chord and that no chord in the "Needs you" range (⌘1…⌘9) maps to a command that sends.
- **Layout is data.** See Rule 2.
- **Enabled state is data.** Whether a command is available (Send while offline, Queue while working) is a store property with its reason, so the menu, the button and the Android port all agree.

The test for any view: if deleting it and rewriting it for another toolkit needs more than reading the store's properties and calling `perform(_:)`, logic has leaked into it.

## Rule 2: IDE-style panes come from a layout model

Panels (the herd sidebar, the conversation, the terminal, a future inspector or pane info) are placed by a `WorkspaceLayout` value in `AppModel`, not by the view hierarchy. The window renders that value. Moving, hiding, resizing or docking a panel is a model operation, reachable as an `AppCommand`, persisted, and tested on Linux. The shape, the operations and how `AppUI` renders it are in [references/layout-model.md](references/layout-model.md).

Until a milestone asks for movable panels, the tree has one fixed shape (sidebar | detail, as design.md says), but it is still the model that decides it, so making panels movable later changes no view code beyond the renderer.

## Rule 3: native macOS chrome

- One main window, a `NavigationSplitView` for the sidebar, a unified toolbar (`.windowToolbarStyle(.unified)`), the standard traffic lights, and a Settings scene when settings land (⌘,).
- Every command is in the menu bar (App, Edit, View, Pane, Go, Agent, Window, Help), with its shortcut shown there. Toolbar and context menus are shortcuts to menu commands, never the only way.
- System fonts, system materials, the user's accent colour, full light and dark mode, SF Symbols only. No custom window chrome, no custom colours for standard controls.
- Esc closes popovers and cancels; Return triggers the default button in dialogs (the composer's send key is its own decision, see docs/milestones.md, M3).
- Right-click works on every row and header, and offers the relevant subset of the menu commands.

The rules adapted from Apple's HIG for menus, windows, toolbars, sidebars, keyboard, pointer and accessibility are in [references/hig-rules.md](references/hig-rules.md).

## Rule 4: density for a developer tool

- Sidebar rows use the sidebar list style at the system's default row height; do not add vertical padding. Status dots are 8 pt, agent icons are small SF Symbols.
- Identifiers (pane ids, paths, session ids, commands) use the system monospaced font; numbers that update (counts, sizes) use `.monospacedDigit()`.
- Secondary text is `.secondary`, not smaller than the system's small size. Nothing below 11 pt.
- Tool rows in the conversation are one line until expanded. Long content truncates in the middle for paths and at the end for prose, with the full text in a help tag (`.help`).
- Controls in panel headers use `.controlSize(.small)`; the main toolbar keeps regular size.
- Empty states use `ContentUnavailableView` with one sentence and, if there is one, the command that fixes it.

## Rule 5: reference apps

Before designing a new surface, check how these solve it, and say which one the design follows. Details in [references/reference-apps.md](references/reference-apps.md).

- **Xcode**: navigator, editor, inspector and debug area as independently hideable panels with ⌘0, ⌘⌥0 and ⇧⌘Y; the model for fabrikater's panels.
- **Zed**: docks on the left, right and bottom, any panel movable between them, and every action in a command palette.
- **Tower**: a dense sidebar of repositories and branches with badges, and a detail view with its own toolbar.
- **Finder**: the source list, a toolbar view switcher, and the preview pane that toggles without disturbing the selection.

## Review checklist

For every UI change, in the PR:

- [ ] No view decides, formats or falls back; the store property it reads is tested on Linux.
- [ ] Every new action is an `AppCommand` case, in the menu bar, and in `Keymap` if it has a shortcut; the keymap test passes.
- [ ] Panel placement comes from `WorkspaceLayout`; nothing hard-codes where a panel sits beyond the renderer.
- [ ] Standard chrome: unified toolbar, sidebar list style, system fonts and colours, light and dark checked (manual on the Mac).
- [ ] Right-click menu, hover state and help tag on new rows and controls.
- [ ] Keyboard: reachable without the mouse, focus order sensible, Esc cancels.
- [ ] Accessibility labels on icon-only controls and status dots (the status as words).
- [ ] An e2e flow in `scripts/e2e/flows/` covers the change, and its CI screenshot was looked at (docs/e2e.md).
- [ ] Reviewed against `swiftui-pro`; repo rules above respected.
