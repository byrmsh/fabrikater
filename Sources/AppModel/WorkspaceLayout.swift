// M4: the first piece of the layout model in `.claude/skills/macos-design/references/layout-model.md`.

/// A panel the detail area can show in place of the other.
public enum DetailPanel: String, CaseIterable, Sendable {
    case conversation
    case terminal

    public var title: String {
        switch self {
        case .conversation: "Conversation"
        case .terminal: "Terminal"
        }
    }
}

/// Where a window's panels go. For now the detail shows the conversation or the terminal, switched by the toolbar's
/// Conversation | Terminal control and View ▸ Show Terminal (⌘T); movable panels come later (docs/milestones.md,
/// "Later"). Each window keeps its own.
public struct WorkspaceLayout: Equatable, Sendable {
    /// The panel the user chose, kept while a pane without a conversation shows the terminal.
    public private(set) var chosen = DetailPanel.conversation
    /// False while the window shows a pane with no conversation to read (a shell, an agent without a parser).
    public private(set) var hasConversation = true

    public init() {}

    /// The panel the detail shows: the user's choice, or the terminal when there is no conversation (M7).
    public var detail: DetailPanel { hasConversation ? chosen : .terminal }

    /// Follows the window's pane: whether it has a conversation to read.
    mutating func show(hasConversation: Bool) {
        self.hasConversation = hasConversation
    }

    /// Applies a layout command and ignores every other.
    mutating func perform(_ command: AppCommand) {
        switch command {
        case .toggleTerminal: chosen = detail == .terminal ? .conversation : .terminal
        case .showPanel(let panel): chosen = panel
        default: break
        }
    }

    /// Whether a layout command applies now; nil for any other command. `hasPane`: the window shows a pane.
    func isEnabled(_ command: AppCommand, hasPane: Bool) -> Bool? {
        switch command {
        case .toggleTerminal, .showPanel: hasPane && hasConversation
        default: nil
        }
    }

    /// The checkmark of Show Terminal; nil for any other command.
    func isChecked(_ command: AppCommand) -> Bool? {
        command == .toggleTerminal ? detail == .terminal : nil
    }
}
