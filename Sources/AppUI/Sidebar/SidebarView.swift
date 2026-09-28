import AppModel
import FabrikaterCore
import SwiftUI

/// Workspaces as sections, tabs with several panes as disclosure groups, single-pane tabs as one row.
struct SidebarView: View {
    let store: AppStore
    @ViewState private var collapsedTabs: Set<String> = []
    @Environment(\.openWindow) private var openWindow

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
                    // A sidebar section heading drops its accessibility label but keeps its value.
                    Text(section.heading)
                        .accessibilityValue(section.heading)
                        .contextMenu {
                            if store.isEnabled(.toggleHiddenWorkspace(section.id)) {
                                CommandButton(
                                    target: MenuTarget(app: store), command: .toggleHiddenWorkspace(section.id))
                            }
                        }
                }
            }
        }
        .listStyle(.sidebar)
        .overlay {
            if store.sections.isEmpty {
                let empty = store.emptySidebar
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
                PaneRowView(
                    pane: pane,
                    renameField: RenameField(label: pane.label) {
                        store.perform(.commitRename(pane.id, $0))
                    } cancel: {
                        store.perform(.cancelRename)
                    }
                )
            } else {
                PaneRowView(pane: pane)
            }
        }
        .tag(pane.id)
        .contextMenu {
            Button(AppCommand.renamePane(pane.id).title) {
                store.perform(.renamePane(pane.id))
            }
            CommandButton(target: MenuTarget(app: store), command: .togglePin(pane.id))
            CommandButton(target: MenuTarget(app: store), command: .toggleHidden(pane.id))
            Button(AppCommand.reloadConversation.title) {
                store.perform(.selectPane(pane.id))
                store.perform(.reloadConversation)
            }
            Button(AppCommand.openInVSCode(pane.id).title) {
                store.perform(.openInVSCode(pane.id))
            }
            .disabled(!store.isEnabled(.openInVSCode(pane.id)))
            Button(AppCommand.openInNewWindow(pane.id).title) {
                openWindow(value: pane.id)
            }
            .disabled(!store.isEnabled(.openInNewWindow(pane.id)))
        }
    }
}
