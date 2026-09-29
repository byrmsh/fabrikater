import AppModel
import SwiftUI

/// The menu bar item: a bell with the Needs You count, and a menu of those panes (MenuBarStatus). Settings' "Show in
/// menu bar" puts it in or takes it out, and so does ⌘-dragging it out of the menu bar.
public struct NeedsYouMenuBar: Scene {
    let session: HostSession

    public init(session: HostSession) {
        self.session = session
    }

    public var body: some Scene {
        MenuBarExtra(isInserted: isInserted) {
            NeedsYouMenu(session: session)
        } label: {
            NeedsYouMenuBarLabel(status: session.menuBar)
        }
        .menuBarExtraStyle(.menu)
    }

    private var isInserted: Binding<Bool> {
        Binding {
            session.showsMenuBarItem
        } set: { shown in
            session.showsMenuBarItem = shown
        }
    }
}
