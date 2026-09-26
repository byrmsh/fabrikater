import AppModel
import FabrikaterCore
import SwiftUI

/// Workspaces as sections, tabs with several panes as disclosure groups, single-pane tabs as one row.
struct SidebarView: View {
    let store: AppStore
    @ViewState private var collapsedTabs: Set<String> = []

    var body: some View {
        List(selection: selection) {
            ForEach(store.sections) { section in
                Section {
                    ForEach(section.rows) { row in
                        switch row {
                        case .pane(let pane):
                            paneRow(pane)
                        case .tab(let tab):
                            DisclosureGroup(isExpanded: expanded(tab.id)) {
                                ForEach(tab.panes) { paneRow($0) }
                            } label: {
                                TabRowView(tab: tab)
                            }
                        }
                    }
                } header: {
                    Text(section.title)
                        .accessibilityLabel(section.title)
                        .accessibilityAddTraits(.isHeader)
                }
            }
        }
        .listStyle(.sidebar)
        .overlay {
            if store.sections.isEmpty {
                let empty = store.connection.emptySidebar
                ContentUnavailableView {
                    Label(empty.title, systemImage: "server.rack")
                } description: {
                    if let detail = empty.detail {
                        Text(detail)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ConnectionFooter(connection: store.connection)
        }
    }

    private var selection: Binding<PaneID?> {
        Binding(get: { store.selection }, set: { store.perform(.selectPane($0)) })
    }

    private func expanded(_ tabID: String) -> Binding<Bool> {
        Binding(
            get: { !collapsedTabs.contains(tabID) },
            set: { isExpanded in
                if isExpanded {
                    collapsedTabs.remove(tabID)
                } else {
                    collapsedTabs.insert(tabID)
                }
            }
        )
    }

    private func paneRow(_ pane: PaneRow) -> some View {
        Group {
            if store.renaming == pane.id {
                RenameField(label: pane.label) {
                    store.perform(.commitRename(pane.id, $0))
                } cancel: {
                    store.perform(.cancelRename)
                }
            } else {
                PaneRowView(pane: pane)
            }
        }
        .tag(pane.id)
        .contextMenu {
            Button(AppCommand.renamePane(pane.id).title) {
                store.perform(.renamePane(pane.id))
            }
            Button(AppCommand.reloadConversation.title) {
                store.perform(.selectPane(pane.id))
                store.perform(.reloadConversation)
            }
        }
    }
}
