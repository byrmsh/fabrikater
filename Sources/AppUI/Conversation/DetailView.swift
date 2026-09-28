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
                if !store.conversation.transcript.todos.isEmpty {
                    TodoPlanView(todos: store.conversation.transcript.todos)
                    Divider()
                }
                TranscriptView(conversation: store.conversation, perform: store.perform)
                Divider()
                ComposerView(composer: store.composer, perform: store.perform)
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
                    Button {
                        store.perform(.reloadConversation)
                    } label: {
                        Label(AppCommand.reloadConversation.title, systemImage: "arrow.clockwise")
                    }
                    .disabled(!store.isEnabled(.reloadConversation))
                    .help(AppCommand.reloadConversation.title)
                }
                ToolbarItem {
                    Button {
                        store.perform(.toggleChanges)
                    } label: {
                        Label(AppCommand.toggleChanges.title, systemImage: "sidebar.trailing")
                    }
                    .disabled(!store.isEnabled(.toggleChanges))
                    .help(AppCommand.toggleChanges.title)
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

    private var isShowingChanges: Binding<Bool> {
        Binding(get: { store.isShowingChanges }, set: { store.perform(.setChangesShown($0)) })
    }
}
