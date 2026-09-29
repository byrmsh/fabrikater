import FabrikaterCore

/// Where a menu bar command goes: the frontmost window's pane. In a pane window, the commands about a pane act on that
/// window's pane and its own conversation, composer and panels; the sidebar's commands stay with the main window. In a
/// past session's window, the conversation commands act on that session and the rest about a pane do nothing.
@MainActor
public struct MenuTarget {
    enum Route: Equatable {
        case app(AppCommand)
        case window(AppCommand)
        case session(AppCommand)
        /// The command needs the main window's sidebar, which a pane window does not have.
        case unavailable
    }

    let app: AppStore
    /// The pane window in front, or nil when the main window is.
    let window: PaneWindowStore?
    /// The past session's window in front, or nil.
    let session: SessionWindowStore?

    public init(app: AppStore, window: PaneWindowStore? = nil, session: SessionWindowStore? = nil) {
        self.app = app
        self.window = window
        self.session = session
    }

    func route(_ command: AppCommand) -> Route {
        if let session {
            if session.handles(command) { return .session(command) }
            let isAboutPane = PaneDetailStores.handles(command) || Self.isAboutSelection(command)
            return isAboutPane ? .unavailable : .app(command)
        }
        guard let window else { return .app(command) }
        if PaneDetailStores.handles(command) { return .window(command) }
        if let aimed = Self.aim(command, at: window.paneID) { return .app(aimed) }
        return Self.isAboutSelection(command) ? .unavailable : .app(command)
    }

    /// Whether `command` acts on the selected pane or its workspace, which a window other than the main one does not
    /// have.
    private static func isAboutSelection(_ command: AppCommand) -> Bool {
        switch command {
        case .togglePin(nil), .toggleHidden(nil), .openInVSCode(nil), .openInNewWindow(nil), .renamePane(nil),
            .toggleHiddenWorkspace(nil), .toggleNotifications(nil), .showPastSessions(nil):
            true
        default: false
        }
    }

    /// `command` aimed at a pane window's own pane, for the selection commands the main window can carry out on any
    /// pane; nil for every other command.
    private static func aim(_ command: AppCommand, at pane: PaneID) -> AppCommand? {
        switch command {
        case .togglePin(nil): .togglePin(pane)
        case .toggleHidden(nil): .toggleHidden(pane)
        case .openInVSCode(nil): .openInVSCode(pane)
        case .openInNewWindow(nil): .openInNewWindow(pane)
        default: nil
        }
    }

    public func perform(_ command: AppCommand) {
        switch route(command) {
        case .app(let command): app.perform(command)
        case .window(let command): window?.perform(command)
        case .session(let command): session?.perform(command)
        case .unavailable: break
        }
    }

    public func isEnabled(_ command: AppCommand) -> Bool {
        switch route(command) {
        case .app(let command): app.isEnabled(command)
        case .window(let command): window?.isEnabled(command) ?? false
        case .session(let command): session?.isEnabled(command) ?? false
        case .unavailable: false
        }
    }

    public func title(of command: AppCommand) -> String {
        switch route(command) {
        case .app(let command): app.title(of: command)
        case .window, .session, .unavailable: command.title
        }
    }

    public func isChecked(_ command: AppCommand) -> Bool? {
        switch route(command) {
        case .app(let command): app.isChecked(command)
        case .window(let command): window?.isChecked(command)
        case .session, .unavailable: nil
        }
    }

    /// The options of the front window's prompt card, which the Pane menu offers; none in a past session's window.
    public var promptOptions: [PromptOption] {
        guard session == nil else { return [] }
        return (window?.prompt ?? app.prompt).options
    }

    /// The pane Open in New Window opens: the front window's.
    public var windowPane: PaneID? {
        app.windowPane(window?.paneID)
    }
}
