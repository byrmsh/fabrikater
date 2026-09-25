# The layout model

How fabrikater gets IDE-style, movable panels while keeping layout logic out of the views. The code below is a sketch of the shape, not a finished API; the first milestone that builds it settles the details and updates this file.

## Values (in `AppModel`, Foundation only)

```swift
public enum PanelID: String, Codable, Sendable, CaseIterable {
    case herd          // the sidebar
    case conversation
    case terminal
    case paneInfo      // a future inspector
}

public enum DockEdge: String, Codable, Sendable { case leading, trailing, bottom }

public indirect enum LayoutNode: Codable, Sendable, Equatable {
    case panel(PanelID)
    /// Children laid out along one axis; `fractions` sum to 1 and have one entry per child.
    case split(axis: Axis, children: [LayoutNode], fractions: [Double])
    /// Children share one area; one is shown, the others are tabs.
    case tabs(children: [PanelID], selected: PanelID)

    public enum Axis: String, Codable, Sendable { case horizontal, vertical }
}

public struct WorkspaceLayout: Codable, Sendable, Equatable {
    public var sidebar: PanelID?            // rendered by NavigationSplitView's sidebar column
    public var sidebarVisible: Bool
    public var main: LayoutNode             // rendered in the detail column
    public var hidden: Set<PanelID>         // panels the user closed; View menu reopens them
}
```

The default layout is design.md's window: `sidebar: .herd`, and `main: .tabs(children: [.conversation, .terminal], selected: .conversation)`, which is the Conversation | Terminal toggle.

## Operations (in the layout store, tested on Linux)

All mutations are pure functions on `WorkspaceLayout`, exposed as `AppCommand` cases:

- `toggle(PanelID)`: hide or show, keeping its last position.
- `move(PanelID, to: DockEdge)` and `move(PanelID, into: PanelID)` (join another panel's tabs).
- `resize(path, fractions)`: from a divider drag; clamps each fraction to a minimum so no panel collapses to nothing by accident.
- `select(PanelID)`: switch tabs.
- `reset()`: back to the default.

Invariants a test checks after every operation: each `PanelID` appears at most once; no empty split or tab group survives (it collapses into its parent); fractions have one entry per child, are positive and sum to 1; the result round-trips through `Codable`.

The layout is saved with the window's state (a JSON blob in `UserDefaults` via the composition root) and restored on launch; an undecodable blob falls back to the default and is logged.

## Rendering (in `AppUI`)

- The sidebar column is a `NavigationSplitView` sidebar, so it gets the standard collapse button, source-list material and ⌃⌘S behaviour for free.
- The detail column renders `main` with one recursive view: `.panel` shows the panel's view, `.tabs` shows a segmented control (or a tab strip when there are more than two) above the selected panel, `.split` shows the children with dividers.
- SwiftUI's `HSplitView`/`VSplitView` do not let the model set or read divider positions, so a split is a small custom container: a `GeometryReader` or `Layout` that sizes children from `fractions`, and a divider view whose drag gesture sends `resize` on end. Keep it in one file (`AppUI/Layout/SplitContainer.swift`). If a native `NSSplitView` is needed later (for its cursor and accessibility behaviour), wrap it in `NSViewControllerRepresentable`, still driven by `fractions`.
- An inspector-style panel on the trailing edge uses `.inspector(isPresented:)` when the layout places `paneInfo` at `.trailing` alone; otherwise it renders like any panel.
- Moving a panel by drag uses `.draggable(PanelID)` on its header and `.dropDestination` on the dock zones, both sending `move`. Every move is also a menu command (View ▸ Move Panel ▸ …), so drag is never required.

## Why not a docking framework

There is no maintained SwiftUI docking library that builds under the Command Line Tools, and an AppKit one would put the layout state inside AppKit objects, which the Android port could not reuse. A value-type tree is small, fully testable on Linux, and ports to Kotlin line by line.
