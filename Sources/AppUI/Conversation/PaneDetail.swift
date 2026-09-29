import AppModel
import FabrikaterCore
import SwiftUI
import TranscriptKit

/// One pane's conversation or terminal and its composer, with its panels (plan, changes, session info) where the
/// window's `PanelLayout` puts them, and its title, status, Reload and Show Changes in the window's title bar and
/// toolbar: the main window's detail and a pane window alike.
struct PaneDetail: View {
    let model: any PaneDetailModel
    let header: PaneHeader
    /// Shown over the conversation's foot, such as a pane window's pane having left Herdr.
    var notice: String?
    /// Only the window in front speaks its prompt and notices, so a pane open in two windows is announced once.
    @Environment(\.appearsActive) private var appearsActive

    var body: some View {
        // The split keeps the conversation as its last child whether or not the left column shows, so opening the
        // column does not rebuild the conversation.
        HSplitView {
            if !model.detail.panels(in: .leading).isEmpty {
                PanelDockView(dock: .leading, model: model)
                    .frame(minWidth: 220, idealWidth: 300, maxWidth: 520)
            }
            main
                .frame(minWidth: 320)
        }
        .inspector(isPresented: isShowingTrailing) {
            PanelDockView(dock: .trailing, model: model)
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
                toolbarButton(.togglePanel(.changes), systemImage: "sidebar.trailing")
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

    /// The conversation or terminal, with the panels docked above it, over the prompt card and composer.
    private var main: some View {
        VStack(spacing: 0) {
            if !model.detail.panels(in: .top).isEmpty {
                PanelDockView(dock: .top, model: model)
                    .background(.bar)
                Divider()
            }
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
        .announcing(model.prompt.announcement, when: appearsActive)
        .announcing(model.prompt.notice, when: appearsActive)
        .announcing(model.composer.notice, when: appearsActive)
        .announcing(notice, when: appearsActive)
    }

    /// The inspector column on the right, open while it has a panel to show; closing it hides its panels.
    private var isShowingTrailing: Binding<Bool> {
        Binding(
            get: { !model.detail.panels(in: .trailing).isEmpty },
            set: { shown in
                if !shown { model.perform(.hidePanels(.trailing)) }
            })
    }
}
