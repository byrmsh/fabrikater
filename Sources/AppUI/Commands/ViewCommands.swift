import AppModel
import SwiftUI

/// The View menu's additions: the conversation's text size, the sidebar, what the sidebar leaves out and how it
/// orders rows, the changes inspector and the terminal.
@MainActor
public struct ViewCommands: Commands {
    let store: AppStore
    /// The pane window in front, if one is; nil while the main window is.
    @FocusedValue(PaneWindowStore.self) private var paneWindow

    public init(store: AppStore) {
        self.store = store
    }

    private var target: MenuTarget {
        MenuTarget(app: store, window: paneWindow)
    }

    public var body: some Commands {
        CommandGroup(before: .toolbar) {
            CommandButton(target: target, command: .actualSizeText)
            CommandButton(target: target, command: .biggerText)
            CommandButton(target: target, command: .smallerText)
            Divider()
        }
        CommandGroup(before: .sidebar) {
            CommandButton(target: target, command: .toggleSidebar)
            CommandButton(target: target, command: .toggleShowHidden)
            CommandButton(target: target, command: .toggleShowShells)
            Menu(PaneOrder.menuTitle) {
                ForEach(PaneOrder.allCases, id: \.self) { order in
                    CommandButton(target: target, command: .sortPanes(order))
                }
            }
            CommandButton(target: target, command: .toggleChanges)
            CommandButton(target: target, command: .toggleTerminal)
            Divider()
        }
    }
}
