import AppModel
import SwiftUI

/// Edit ▸ Find: find in the front window's conversation (⌘F, ⌘G, ⇧⌘G). It takes the place of the text system's own
/// find and text editing items, which would otherwise claim ⌘F for a text field.
@MainActor
public struct FindCommands: Commands {
    let session: HostSession
    /// The pane window in front, if one is; nil while the main window is.
    @FocusedValue(PaneWindowStore.self) private var paneWindow
    /// The past session's window in front, if one is.
    @FocusedValue(SessionWindowStore.self) private var sessionWindow

    public init(session: HostSession) {
        self.session = session
    }

    /// The store of the host connected to now.
    private var store: AppStore { session.store }

    private var target: MenuTarget {
        MenuTarget(app: store, window: paneWindow, session: sessionWindow)
    }

    public var body: some Commands {
        CommandGroup(replacing: .textEditing) {
            Menu(AppCommand.searchConversation("").title) {
                CommandButton(target: target, command: .findInConversation)
                CommandButton(target: target, command: .findNext)
                CommandButton(target: target, command: .findPrevious)
            }
        }
    }
}
