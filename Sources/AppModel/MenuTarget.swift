import FabrikaterCore

/// Where a menu bar command goes: the frontmost window's pane. In a pane window, the commands about a pane act on that
/// window's pane and its own conversation, composer and panels; the sidebar's commands stay with the main window.
@MainActor
public struct MenuTarget {
    enum Route: Equatable {
        case app(AppCommand)
        case window(AppCommand)
        /// The command needs the main window's sidebar, which a pane window does not have.
        case unavailable
    }

    let app: AppStore
    /// The pane window in front, or nil when the main window is.
    let window: PaneWindowStore?

    public init(app: AppStore, window: PaneWindowStore? = nil) {
        self.app = app
        self.window = window
    }

    func route(_ command: AppCommand) -> Route {
        guard let window else { return .app(command) }
        let pane = window.paneID
        switch command {
        case .send, .sendKey, .reloadConversation, .copyConversation, .toggleChanges, .setChangesShown,
            .toggleSessionFacts, .setSessionFactsShown, .toggleTerminal, .showPanel:
            return .window(command)
        case .togglePin(nil): return .app(.togglePin(pane))
        case .toggleHidden(nil): return .app(.toggleHidden(pane))
        case .openInVSCode(nil): return .app(.openInVSCode(pane))
        case .openInNewWindow(nil): return .app(.openInNewWindow(pane))
        case .renamePane(nil), .toggleHiddenWorkspace(nil): return .unavailable
        default: return .app(command)
        }
    }

    public func perform(_ command: AppCommand) {
        switch route(command) {
        case .app(let command): app.perform(command)
        case .window(let command): window?.perform(command)
        case .unavailable: break
        }
    }

    public func isEnabled(_ command: AppCommand) -> Bool {
        switch route(command) {
        case .app(let command): app.isEnabled(command)
        case .window(let command): window?.isEnabled(command) ?? false
        case .unavailable: false
        }
    }

    public func title(of command: AppCommand) -> String {
        switch route(command) {
        case .app(let command): app.title(of: command)
        case .window, .unavailable: command.title
        }
    }

    public func isChecked(_ command: AppCommand) -> Bool? {
        switch route(command) {
        case .app(let command): app.isChecked(command)
        case .window(let command): window?.isChecked(command)
        case .unavailable: nil
        }
    }

    /// The pane Open in New Window opens: the front window's.
    public var windowPane: PaneID? {
        app.windowPane(window?.paneID)
    }
}
