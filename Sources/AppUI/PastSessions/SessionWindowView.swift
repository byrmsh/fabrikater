import AppModel
import SwiftUI

/// A window reading one past session's conversation, opened from the Past Sessions sheet. There is no composer: the
/// session is not running in a pane.
public struct SessionWindowView: View {
    let session: HostSession
    let id: SessionWindowID

    public init(session: HostSession, id: SessionWindowID) {
        self.session = session
        self.id = id
    }

    public var body: some View {
        HostWindow(
            session: session, make: { [id] in $0.sessionWindow(id) }, isClosed: { $0.isClosed },
            content: { SessionWindowContent(window: $0) })
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
