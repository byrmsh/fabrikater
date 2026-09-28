import AppModel
import FabrikaterCore
import SwiftUI
import TranscriptKit

/// A window showing one pane's conversation, opened with Open in New Window (docs/design.md, "Pane windows"). It holds
/// its own store, so closing the window frees it.
public struct PaneWindowView: View {
    let store: AppStore
    let paneID: PaneID
    @ViewState private var window: PaneWindowStore?

    public init(store: AppStore, paneID: PaneID) {
        self.store = store
        self.paneID = paneID
    }

    public var body: some View {
        Group {
            if let window {
                // A navigation container gives the window the same title bar and toolbar as the main window's detail.
                NavigationStack {
                    PaneWindowContent(window: window)
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
                window = store.paneWindow(paneID)
            }
        }
    }
}

/// The pane's plan and conversation, with its title, status and Reload in the window's title bar and toolbar.
struct PaneWindowContent: View {
    let window: PaneWindowStore

    var body: some View {
        VStack(spacing: 0) {
            if !window.conversation.transcript.todos.isEmpty {
                TodoPlanView(todos: window.conversation.transcript.todos)
                Divider()
            }
            TranscriptView(conversation: window.conversation, perform: window.perform)
        }
        .overlay(alignment: .bottom) {
            if let notice = window.notice {
                StaleBanner(message: notice)
            }
        }
        .navigationTitle(window.header?.title ?? window.paneID.rawValue)
        .navigationSubtitle(window.header?.location ?? "")
        .toolbar {
            if let header = window.header {
                ToolbarItem {
                    PaneStatusView(header: header)
                }
            }
            ToolbarItem {
                Button {
                    window.perform(.reloadConversation)
                } label: {
                    Label(AppCommand.reloadConversation.title, systemImage: "arrow.clockwise")
                }
                .disabled(!window.isEnabled(.reloadConversation))
                .help(AppCommand.reloadConversation.title)
            }
        }
    }
}
