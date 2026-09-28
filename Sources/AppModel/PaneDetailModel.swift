/// A window's view of one pane: the main window's selection (`AppStore`) or a pane window's pane (`PaneWindowStore`).
/// The detail views read it alone, so both windows show the same conversation, composer, panels and toolbar.
@MainActor
public protocol PaneDetailModel: AnyObject {
    /// Nil while there is no pane to show.
    var header: PaneHeader? { get }
    /// The window's own stores for its pane.
    var detail: PaneDetailStores { get }
    func perform(_ command: AppCommand)
    func isEnabled(_ command: AppCommand) -> Bool
}

extension PaneDetailModel {
    public var conversation: ConversationStore { detail.conversation }
    public var composer: ComposerStore { detail.composer }
    public var prompt: PromptCardStore { detail.prompt }
    public var terminal: TerminalStore { detail.terminal }
    public var panels: PanePanels { detail.panels }
    /// Which panel the detail shows: the conversation or the terminal.
    public var layout: WorkspaceLayout { detail.layout }

    /// Whether the prompt card's Show Terminal button can switch to the terminal: not while the detail shows it.
    public var canShowTerminalForPrompt: Bool {
        isEnabled(PromptCardStore.terminalCommand) && layout.detail != .terminal
    }
}

extension AppStore: PaneDetailModel {}
extension PaneWindowStore: PaneDetailModel {}
