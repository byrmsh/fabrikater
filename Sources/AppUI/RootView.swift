import SwiftUI

/// The main window: the herd sidebar and the selected pane (docs/design.md, "Window").
public struct RootView: View {
    @ViewState private var columnVisibility = NavigationSplitViewVisibility.all

    public init() {}

    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List {}
                .navigationSplitViewColumnWidth(min: 220, ideal: 280)
        } detail: {
            ContentUnavailableView("No Pane Selected", systemImage: "sidebar.left")
        }
    }
}
