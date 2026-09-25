# macOS HIG rules, adapted for fabrikater

Adapted from `skills/macos/SKILL.md` in ehmo/platform-design-skills (https://github.com/ehmo/platform-design-skills, commit dc2be825d8b439caea78e9eaa8fb3ac23b0ff3e9), MIT licence in [LICENSE.platform-design-skills](LICENSE.platform-design-skills). Condensed, rewritten for fabrikater, and changed to follow the repo's rules (`@ViewState`, commands and shortcuts as data in `AppModel`). Rules that do not apply to fabrikater (documents, Quick Look, Spotlight, Services, Share) were left out.

## Menu bar

1. The standard menus exist: App, Edit, View, Window, Help. fabrikater adds **Pane** (send keys, detail mode, reveal in terminal), **Go** (next pane, next "Needs you", jump by number) and **Agent** (commands that act on the selected agent). There is no File menu: fabrikater is not document-based.
2. Every action reachable by mouse is a menu item, and every frequent one has a shortcut shown in the menu. Standard actions keep their standard shortcuts (⌘C, ⌘V, ⌘Z, ⌘F, ⌘G, ⌘,, ⌘W, ⌘M, ⌘Q, ⌃⌘F).
3. Menu items reflect state: disabled when unavailable (Send while offline), titles that say what they do ("Show Terminal" / "Show Conversation"), checkmarks for toggles.
4. Command names and places are stable across releases. Do not move a command between menus to follow a context.
5. The App menu keeps its standard items: About, Settings (⌘,), Services, Hide (⌘H), Hide Others (⌥⌘H), Show All, Quit (⌘Q).

In fabrikater all of this is generated from `AppCommand` and `Keymap`: `.commands { CommandMenu("Pane") { … } }` lists buttons that call `store.perform(.command)` and take their shortcut from the keymap.

## Windows

1. The main window is freely resizable, with a minimum size that keeps sidebar and detail usable (about 700 × 450), and a default of 1100 × 720. No maximum.
2. Full screen and tiling work (SwiftUI windows get this by default).
3. The window's frame, sidebar width, column visibility and the layout model are restored on relaunch.
4. The traffic lights stay visible and in place; no custom title bar.
5. The window title is the selected pane's label, and the subtitle its workspace and tab (`.navigationTitle`, `.navigationSubtitle`).

## Toolbar

1. Unified title bar and toolbar (`.windowToolbarStyle(.unified)`).
2. The Conversation | Terminal switch is a segmented `Picker` in the toolbar or the detail header, not a tab bar.
3. Search in the conversation uses `.searchable` in the toolbar's trailing area, bound to ⌘F.
4. Toolbar items use `Label` (icon and title), so the title shows in "Icon and Text" mode and as the accessibility label.
5. Customisable toolbars (`.toolbar(id:)`) only when there are enough items to make it worthwhile; not in the first version.

## Sidebar

1. Leading edge, collapsible with the toolbar button and ⌃⌘S, width about 220–320 pt (`.navigationSplitViewColumnWidth(min: 220, ideal: 280, max: 400)`).
2. Source-list style (`.listStyle(.sidebar)`), with `Section`s for workspaces and disclosure for tabs.
3. Counts are `.badge(_:)` values from the store (panes needing you per workspace).
4. Reordering by drag only where the order is fabrikater's own; workspace and tab order is Herdr's and is not reordered here.

## Keyboard

1. Modifier conventions: ⌘ + letter for primary actions, ⇧⌘ for variants, ⌥⌘ for alternative modes, ⌃⌘ for window and view controls.
2. Full keyboard navigation: Tab and ⇧Tab between areas, arrows within lists, focus visible. Use `@FocusState` for the composer and the filter field.
3. Esc dismisses popovers and sheets and cancels in-progress operations; in dialogs it is Cancel (`.keyboardShortcut(.cancelAction)`).
4. Return triggers the default button in dialogs (`.keyboardShortcut(.defaultAction)`), which is always the safe action.
5. Arrow keys move the selection in lists; ← and → collapse and expand disclosure rows.

## Pointer

1. Interactive rows and controls show a hover state. Hover state is view-local: `@ViewState private var isHovered = false` with `.onHover { isHovered = $0 }`.
2. Right-click opens a context menu with the relevant subset of menu commands on every row, header and panel.
3. Drag and drop where it moves something the user owns (a panel to another dock, text into the composer).
4. Cursors signal affordance: I-beam over selectable text, resize cursors over split dividers.
5. Help tags (`.help`) on icon-only controls and truncated text.

## Notifications and alerts

1. Notify only for events outside the user's current focus that need them (a pane blocked, a turn done), as design.md defines; never for routine activity.
2. Prefer inline state (a status dot, an inline error under the composer) to alerts. An alert is for a destructive or irreversible choice only.
3. The Dock badge shows the "Needs you" count and clears as panes are opened.

## Popovers

1. Popovers hold transient, context-bound content (a tool call's full input, a status explanation), are anchored to the control that opened them, close with Esc and on outside click, and size to their content.

## Visual design

1. System fonts (`.body`, `.callout`, `.caption`), the system monospaced font for code and identifiers, and text styles rather than fixed point sizes.
2. System materials for the sidebar and bars; no custom translucency.
3. The user's accent colour for selection and primary controls; status colours only for status.
4. Full dark mode support, checked in both appearances.
5. Consistent spacing from the system's defaults; do not hand-tune padding per view.

## Accessibility

1. Every icon-only control and status dot has an accessibility label in words ("Blocked", "Working").
2. Full Keyboard Access works: every control is reachable and operable by keyboard.
3. Animations (the working dot) respect Reduce Motion; materials respect Reduce Transparency; colours respect Increase Contrast.
4. Focus order follows the visual order: sidebar, detail header, content, composer.
