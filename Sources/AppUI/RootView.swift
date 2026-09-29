import AppKit
import AppModel
import SwiftUI

/// The main window for the host connected to now: connecting to another host builds it afresh on the new host's store.
public struct MainWindow: View {
    let session: HostSession
    /// The main window's scene id, which SwiftUI also prefixes its windows' identifiers with.
    public static let sceneID = "main"

    public init(session: HostSession) {
        self.session = session
    }

    public var body: some View {
        RootView(store: session.store)
            .id(ObjectIdentifier(session.store))
    }
}

/// The main window: the herd sidebar and the selected pane (docs/design.md, "Window").
public struct RootView: View {
    let store: AppStore
    /// The window's text size, sidebar and detail panel, restored with the window.
    @SceneStorage("textScaleStep") private var savedTextScaleStep = TextScale.actual.step
    @SceneStorage("isSidebarVisible") private var savedSidebarVisible = true
    @SceneStorage("detailPanel") private var savedDetailPanel = DetailPanel.conversation.rawValue

    public init(store: AppStore) {
        self.store = store
    }

    public var body: some View {
        NavigationSplitView(columnVisibility: columnVisibility) {
            SidebarView(store: store)
                .navigationSplitViewColumnWidth(min: 220, ideal: 280)
        } detail: {
            DetailView(store: store)
                .sheet(isPresented: isBrowsingSessions) {
                    PastSessionsView(store: store)
                }
        }
        .sheet(isPresented: isSwitching) {
            QuickSwitcherView(store: store)
        }
        .onAppear {
            store.perform(.setTextScale(TextScale(step: savedTextScaleStep)))
            store.perform(.setSidebarVisible(savedSidebarVisible))
            store.perform(.showPanel(DetailPanel(rawValue: savedDetailPanel) ?? .conversation))
        }
        .onChange(of: store.textScale) { _, scale in savedTextScaleStep = scale.step }
        .onChange(of: store.isSidebarVisible) { _, visible in savedSidebarVisible = visible }
        .onChange(of: store.layout.chosen) { _, panel in savedDetailPanel = panel.rawValue }
        .onChange(of: store.needsYou.badge, initial: true) { _, badge in NSApp.dockTile.badgeLabel = badge }
        .announcingChanges(of: store.announced)
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

    private var isBrowsingSessions: Binding<Bool> {
        Binding(
            get: { store.pastSessions.sheet != nil },
            set: { isPresented in
                if !isPresented { store.perform(.closePastSessions) }
            }
        )
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
