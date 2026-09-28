import AppModel
import FabrikaterCore
import SwiftUI
import TranscriptKit

/// One pane's plan, conversation and composer, with its changes inspector, and its title, status, Reload and Show
/// Changes in the window's title bar and toolbar: the main window's detail and a pane window alike.
struct PaneDetail: View {
    let model: any PaneDetailModel
    let header: PaneHeader
    /// Shown over the conversation's foot, such as a pane window's pane having left Herdr.
    var notice: String?

    var body: some View {
        VStack(spacing: 0) {
            ConversationColumn(conversation: model.conversation, perform: perform)
                .overlay(alignment: .bottom) {
                    if let notice {
                        StaleBanner(message: notice)
                    }
                }
            Divider()
            ComposerView(composer: model.composer, perform: perform)
        }
        .inspector(isPresented: isShowingChanges) {
            ChangesView(panel: model.conversation.changesPanel, perform: perform)
                .id(model.conversation.paneID)
                .inspectorColumnWidth(min: 240, ideal: 320, max: 560)
        }
        .navigationTitle(header.title)
        .navigationSubtitle(header.location)
        .toolbar {
            ToolbarItem {
                SessionFactsButton(model: model, header: header)
            }
            ToolbarItem {
                toolbarButton(.reloadConversation, systemImage: "arrow.clockwise")
            }
            ToolbarItem {
                toolbarButton(.toggleChanges, systemImage: "sidebar.trailing")
            }
        }
    }

    private func perform(_ command: AppCommand) {
        model.perform(command)
    }

    private func toolbarButton(_ command: AppCommand, systemImage: String) -> ToolbarCommandButton {
        ToolbarCommandButton(
            command: command, systemImage: systemImage, isEnabled: model.isEnabled(command), perform: perform)
    }

    private var isShowingChanges: Binding<Bool> {
        Binding(get: { model.panels.isShowingChanges }, set: { model.perform(.setChangesShown($0)) })
    }
}
