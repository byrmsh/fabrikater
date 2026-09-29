import AppKit
import AppModel
import SwiftUI

/// The menu bar item's menu: the host and its Needs You panes; choosing a pane brings the main window forward on it.
struct NeedsYouMenu: View {
    let session: HostSession
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let status = session.menuBar
        Section(status.heading) {
            ForEach(status.rows) { row in
                Button(row.title) {
                    session.store.perform(.selectPane(row.id))
                    showMainWindow()
                }
            }
        }
        Divider()
        Button(MenuBarStatus.openTitle) { showMainWindow() }
    }

    /// Activates the app and fronts a main window, opening one when all were closed.
    private func showMainWindow() {
        NSApp.activate()
        let main = NSApp.windows.first { $0.identifier?.rawValue.hasPrefix(MainWindow.sceneID) == true }
        if let main {
            main.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: MainWindow.sceneID)
        }
    }
}
