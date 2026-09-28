import AppModel
import SwiftUI

/// A window reading one past session's conversation, opened from the Past Sessions sheet. It holds its own store, so
/// closing the window frees it. There is no composer: the session is not running in a pane.
public struct SessionWindowView: View {
    let store: AppStore
    let id: SessionWindowID
    @ViewState private var window: SessionWindowStore?

    public init(store: AppStore, id: SessionWindowID) {
        self.store = store
        self.id = id
    }

    public var body: some View {
        Group {
            if let window {
                // A navigation container gives the window the same title bar and toolbar as a pane window.
                NavigationStack {
                    SessionWindowContent(window: window)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .environment(\.textScale, store.textScale.factor)
        .frame(minWidth: 420, minHeight: 320)
        .onAppear {
            if window == nil {
                window = store.sessionWindow(id)
            }
        }
    }
}

private struct SessionWindowContent: View {
    let window: SessionWindowStore

    var body: some View {
        VStack(spacing: 0) {
            ConversationColumn(conversation: window.conversation, perform: window.perform)
        }
        .navigationTitle(window.title)
        .navigationSubtitle(window.subtitle)
        .toolbar {
            ToolbarItem {
                toolbarButton(.copyConversation, systemImage: "doc.on.doc")
            }
            ToolbarItem {
                toolbarButton(.reloadConversation, systemImage: "arrow.clockwise")
            }
        }
    }

    private func toolbarButton(_ command: AppCommand, systemImage: String) -> ToolbarCommandButton {
        ToolbarCommandButton(
            command: command, systemImage: systemImage, isEnabled: window.isEnabled(command), perform: window.perform)
    }
}
