import AppModel
import FabrikaterCore
import SwiftUI

/// The selected pane's conversation and composer; its title, status and agent are in the window's title bar and toolbar.
struct DetailView: View {
    let store: AppStore

    var body: some View {
        if let header = store.header {
            VStack(spacing: 0) {
                TranscriptView(conversation: store.conversation, perform: store.perform)
                Divider()
                ComposerView(store: store)
            }
            .environment(\.textScale, store.textScale.factor)
            .navigationTitle(header.title)
            .navigationSubtitle(header.location)
            .toolbar {
                ToolbarItem {
                    PaneStatusView(store: store, header: header)
                }
                ToolbarItem {
                    Button {
                        store.perform(.reloadConversation)
                    } label: {
                        Label(AppCommand.reloadConversation.title, systemImage: "arrow.clockwise")
                    }
                    .disabled(!store.isEnabled(.reloadConversation))
                    .help(AppCommand.reloadConversation.title)
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
}
