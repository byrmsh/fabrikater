import AppModel
import SwiftUI

/// The main window's detail: the selected pane, or a prompt to choose one.
struct DetailView: View {
    let store: AppStore

    var body: some View {
        if let header = store.header {
            PaneDetail(model: store, header: header)
                .environment(\.textScale, store.textScale.factor)
        } else {
            ContentUnavailableView(
                "No Pane Selected",
                systemImage: "sidebar.left",
                description: Text("Choose a pane in the sidebar to read its conversation.")
            )
        }
    }
}
