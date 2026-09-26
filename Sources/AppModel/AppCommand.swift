import FabrikaterCore

/// Every user action, whichever menu, button or shortcut triggers it (`.claude/skills/macos-design`, Rule 1).
public enum AppCommand: Hashable, Sendable {
    case selectPane(PaneID?)
    case selectNextPane
    case selectPreviousPane
    case reloadConversation
    /// Sends the composer's draft to the selected pane.
    case send
    /// Opens the inline name field on a pane's row; nil means the selected pane.
    case renamePane(PaneID?)
    /// Sets the name typed into the field; blank text clears it.
    case commitRename(PaneID, String)
    case cancelRename
    /// Pins a pane to the top of the sidebar, or unpins it; nil means the selected pane.
    case togglePin(PaneID?)
    case openQuickSwitcher
    case closeQuickSwitcher
    /// The text typed into the switcher's search field.
    case searchQuickSwitcher(String)
    /// Moves the switcher's highlight by this many results.
    case moveQuickSwitcherHighlight(Int)
    /// Selects a result and closes the switcher; nil means the highlighted result.
    case chooseQuickSwitcherResult(PaneID?)
    /// Copies one conversation entry, by id, as markdown.
    case copyMessage(String)
    case copyConversation

    /// The menu title.
    public var title: String {
        switch self {
        case .selectPane: "Select Pane"
        case .selectNextPane: "Next Pane"
        case .selectPreviousPane: "Previous Pane"
        case .reloadConversation: "Reload Conversation"
        case .send: "Send"
        case .renamePane: "Rename…"
        case .commitRename: "Rename"
        case .cancelRename: "Cancel Rename"
        case .togglePin: "Pin"
        case .openQuickSwitcher: "Open Quickly…"
        case .closeQuickSwitcher: "Close Switcher"
        case .searchQuickSwitcher: "Search Panes"
        case .moveQuickSwitcherHighlight: "Move Highlight"
        case .chooseQuickSwitcherResult: "Open Pane"
        case .copyMessage: "Copy Message"
        case .copyConversation: "Copy Conversation as Markdown"
        }
    }
}
