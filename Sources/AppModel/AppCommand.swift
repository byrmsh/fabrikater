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
    case toggleSidebar
    /// The sidebar was shown or hidden by the window itself (its toolbar button, or restoring the window).
    case setSidebarVisible(Bool)
    case biggerText
    case smallerText
    case actualSizeText
    /// Restores a saved text size, clamped to the steps.
    case setTextScale(TextScale)

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
        case .toggleSidebar: "Toggle Sidebar"
        case .setSidebarVisible(let visible): visible ? "Show Sidebar" : "Hide Sidebar"
        case .biggerText: "Bigger"
        case .smallerText: "Smaller"
        case .actualSizeText: "Actual Size"
        case .setTextScale: "Text Size"
        }
    }
}
