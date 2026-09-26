import AppModel
import SwiftUI

/// The main window: the herd sidebar and the selected pane (docs/design.md, "Window").
public struct RootView: View {
    let store: AppStore
    @ViewState private var columnVisibility = NavigationSplitViewVisibility.all

    public init(store: AppStore) {
        self.store = store
    }

    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(store: store)
                .navigationSplitViewColumnWidth(min: 220, ideal: 280)
        } detail: {
            DetailView(store: store)
        }
        .task { await store.run() }
    }
}
