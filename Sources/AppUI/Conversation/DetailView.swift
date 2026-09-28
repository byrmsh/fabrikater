import AppModel
import FabrikaterCore
import SwiftUI
import TranscriptKit

/// The selected pane's conversation and composer; its title, status and agent are in the window's title bar and toolbar.
struct DetailView: View {
    let store: AppStore

    var body: some View {
        if let header = store.header {
            VStack(spacing: 0) {
                ConversationColumn(conversation: store.conversation, perform: store.perform)
                Divider()
                ComposerView(store: store)
            }
            .environment(\.textScale, store.textScale.factor)
            .inspector(isPresented: isShowingChanges) {
                ChangesView(panel: store.conversation.changesPanel, perform: store.perform)
                    .id(store.selection)
                    .inspectorColumnWidth(min: 240, ideal: 320, max: 560)
            }
            .navigationTitle(header.title)
            .navigationSubtitle(header.location)
            .toolbar {
                ToolbarItem {
                    SessionFactsButton(store: store, header: header)
                }
                ToolbarItem {
                    toolbarButton(.reloadConversation, systemImage: "arrow.clockwise")
                }
                ToolbarItem {
                    toolbarButton(.toggleChanges, systemImage: "sidebar.trailing")
                }
            }
        } else {
            ContentUnavailableView(
                "No Pane Selected",
                systemImage: "sidebar.left",
                description: Text("Choose a pane in the sidebar to read its conversation.")
            )
        }
    }

    private func toolbarButton(_ command: AppCommand, systemImage: String) -> ToolbarCommandButton {
        ToolbarCommandButton(
            command: command, systemImage: systemImage, isEnabled: store.isEnabled(command), perform: store.perform)
    }

    private var isShowingChanges: Binding<Bool> {
        Binding(get: { store.isShowingChanges }, set: { store.perform(.setChangesShown($0)) })
    }
}
