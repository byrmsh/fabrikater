# Reference apps

What to take from each, and what not to. When a design follows one of them, say so in the PR.

## Xcode

- Take: three independently hideable areas around the editor (navigator ⌘0, inspector ⌥⌘0, debug area ⇧⌘Y), each remembered per window; the navigator's filter field at the bottom; issue badges in the navigator; View menu items that name each area and show its shortcut.
- Leave: the density of the inspector's forms (fabrikater has little to edit), the tab-and-window-tab mix.

## Zed

- Take: docks on the leading, trailing and bottom edges, any panel movable between them from its header's context menu; a command palette (⇧⌘P) listing every command with its shortcut, which fabrikater gets almost for free from `AppCommand` and `Keymap`; quiet chrome that gives the content the space.
- Leave: its custom-drawn UI and non-native controls; fabrikater uses standard AppKit and SwiftUI controls.

## Tower

- Take: a dense sidebar of many items grouped in sections with counts and status, collapsible sections, a detail area with its own compact header; clear status colour used sparingly.
- Leave: modal sheets for routine actions.

## Finder

- Take: the source list look and behaviour (selection, disclosure, drag to reorder where it makes sense), the toolbar view switcher, the preview pane that toggles without changing the selection, type-to-select in lists.
- Leave: the column browser; the herd is a tree, not a path.
