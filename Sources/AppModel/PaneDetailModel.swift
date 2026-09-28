/// A window's view of one pane: the main window's selection (`AppStore`) or a pane window's pane (`PaneWindowStore`).
/// The detail views read it alone, so both windows show the same conversation, composer, panels and toolbar.
@MainActor
public protocol PaneDetailModel: AnyObject {
    /// Nil while there is no pane to show.
    var header: PaneHeader? { get }
    var conversation: ConversationStore { get }
    var composer: ComposerStore { get }
    var panels: PanePanels { get }
    /// Which panel the detail shows: the conversation or the terminal.
    var layout: WorkspaceLayout { get }
    var terminal: TerminalStore { get }
    func perform(_ command: AppCommand)
    func isEnabled(_ command: AppCommand) -> Bool
}

extension AppStore: PaneDetailModel {}
extension PaneWindowStore: PaneDetailModel {}
