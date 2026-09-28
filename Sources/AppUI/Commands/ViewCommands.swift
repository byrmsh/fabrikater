import AppModel
import SwiftUI

/// The View menu's additions: the conversation's text size, the sidebar, what the sidebar leaves out, and the changes
/// inspector.
@MainActor
public struct ViewCommands: Commands {
    let store: AppStore

    public init(store: AppStore) {
        self.store = store
    }

    public var body: some Commands {
        CommandGroup(before: .toolbar) {
            CommandButton(store: store, command: .actualSizeText)
            CommandButton(store: store, command: .biggerText)
            CommandButton(store: store, command: .smallerText)
            Divider()
        }
        CommandGroup(before: .sidebar) {
            CommandButton(store: store, command: .toggleSidebar)
            CommandButton(store: store, command: .toggleShowHidden)
            CommandButton(store: store, command: .toggleShowShells)
            CommandButton(store: store, command: .toggleChanges)
            Divider()
        }
    }
}
