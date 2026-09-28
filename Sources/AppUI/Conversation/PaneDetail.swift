import AppModel
import FabrikaterCore
import SwiftUI
import TranscriptKit

/// One pane's plan and conversation or its terminal, and its composer, with its changes inspector, and its title, status, Reload and Show
/// Changes in the window's title bar and toolbar: the main window's detail and a pane window alike.
struct PaneDetail: View {
    let model: any PaneDetailModel
    let header: PaneHeader
    /// Shown over the conversation's foot, such as a pane window's pane having left Herdr.
    var notice: String?

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch model.layout.detail {
                case .conversation: ConversationColumn(conversation: model.conversation, perform: perform)
                case .terminal: TerminalPanel(terminal: model.terminal, perform: perform)
                }
            }
            .overlay(alignment: .bottom) {
                if let notice {
                    StaleBanner(message: notice)
                }
            }
            Divider()
            if model.prompt.isShown {
                PromptCardView(
                    prompt: model.prompt, canShowTerminal: model.canShowTerminalForPrompt, perform: perform)
            }
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
            ToolbarItem(placement: .principal) {
                DetailPanelPicker(
                    layout: model.layout, isEnabled: model.isEnabled(.toggleTerminal), perform: perform)
            }
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
