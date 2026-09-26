import AppModel
import SwiftUI

/// The selected pane: its header, then its conversation.
struct DetailView: View {
    let store: AppStore

    var body: some View {
        if let header = store.header {
            VStack(spacing: 0) {
                PaneHeaderView(header: header)
                Divider()
                TranscriptView(conversation: store.conversation)
            }
            .navigationTitle(header.title)
            .navigationSubtitle(header.location)
            .toolbar {
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

struct PaneHeaderView: View {
    let header: PaneHeader

    var body: some View {
        HStack(spacing: 8) {
            StatusDot(status: header.status)
            Text(header.title)
                .font(.headline)
                .lineLimit(1)
            Text(header.agent)
                .foregroundStyle(.secondary)
            Spacer()
            Text(header.status.title)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}
