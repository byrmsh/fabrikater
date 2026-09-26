import AppModel
import SwiftUI

/// The main window: the herd sidebar and the selected pane (docs/design.md, "Window").
public struct RootView: View {
    let store: AppStore
    /// The window's text size and sidebar, restored with the window.
    @SceneStorage("textScaleStep") private var savedTextScaleStep = TextScale.actual.step
    @SceneStorage("isSidebarVisible") private var savedSidebarVisible = true

    public init(store: AppStore) {
        self.store = store
    }

    public var body: some View {
        NavigationSplitView(columnVisibility: columnVisibility) {
            SidebarView(store: store)
                .navigationSplitViewColumnWidth(min: 220, ideal: 280)
        } detail: {
            DetailView(store: store)
        }
        .sheet(isPresented: isSwitching) {
            QuickSwitcherView(store: store)
        }
        .onAppear {
            store.perform(.setTextScale(TextScale(step: savedTextScaleStep)))
            store.perform(.setSidebarVisible(savedSidebarVisible))
        }
        .onChange(of: store.textScale) { _, scale in savedTextScaleStep = scale.step }
        .onChange(of: store.isSidebarVisible) { _, visible in savedSidebarVisible = visible }
        .task { await store.run() }
    }

    /// The store decides; the split view's own collapse button reports back through the same command.
    private var columnVisibility: Binding<NavigationSplitViewVisibility> {
        Binding {
            store.isSidebarVisible ? .all : .detailOnly
        } set: { visibility in
            store.perform(.setSidebarVisible(visibility != .detailOnly))
        }
    }

    private var isSwitching: Binding<Bool> {
        Binding(
            get: { store.switcher != nil },
            set: { isPresented in
                if !isPresented { store.perform(.closeQuickSwitcher) }
            }
        )
    }
}
