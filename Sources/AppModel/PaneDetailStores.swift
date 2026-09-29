import FabrikaterCore
import HerdrKit
import Observation
import TranscriptKit

/// Everything one window keeps about the pane it shows: its conversation, composer, prompt card, terminal, panels and
/// layout, and the commands that act on them. The main window (`AppStore`) and each pane window (`PaneWindowStore`) own
/// one, so a feature of the pane detail is added or removed here once for both.
@MainActor
@Observable
public final class PaneDetailStores {
    public let conversation: ConversationStore
    /// Sends prompts to the pane; its draft is the pane's, shared with every window.
    public let composer: ComposerStore
    /// Answers the pane's prompt.
    public let prompt: PromptCardStore
    public let terminal: TerminalStore
    /// The changes inspector and session facts popover.
    public private(set) var panels = PanePanels()
    /// Whether the detail shows the conversation or the terminal.
    public private(set) var layout = WorkspaceLayout()

    private let clipboard: any Clipboard

    init(
        conversation: ConversationStore, composer: ComposerStore, prompt: PromptCardStore, terminal: TerminalStore,
        clipboard: any Clipboard
    ) {
        self.conversation = conversation
        self.composer = composer
        self.prompt = prompt
        self.terminal = terminal
        self.clipboard = clipboard
    }

    /// Stops every read and follow for good, when the window or the host it reads from goes. A send already on its way
    /// finishes.
    func close() {
        conversation.close()
        prompt.close()
        terminal.close()
    }

    /// Whether `command` acts on a window's pane detail rather than on the sidebar or the app.
    static func handles(_ command: AppCommand) -> Bool {
        switch command {
        case .send, .sendKey, .answerPrompt, .toggleChanges, .setChangesShown, .toggleSessionFacts,
            .setSessionFactsShown, .copyPath, .toggleTerminal, .showPanel, .setTerminalVisible, .reloadConversation,
            .loadEarlier, .copyMessage, .copyConversation, .expandEntry, .collapseEntry, .findInConversation,
            .searchConversation, .findNext, .findPrevious, .closeFind:
            true
        default: false
        }
    }

    /// Shows `pane`'s conversation and terminal, or none; a pane with no conversation to read shows the terminal.
    func show(_ pane: Herd.Pane?) {
        if pane == nil {
            panels.losePane()
        }
        conversation.show(pane)
        layout.show(hasConversation: pane == nil || ConversationStore.hasParser(pane))
        terminal.show(pane?.id, columns: pane?.columns)
    }

    /// Follows the pane's status and the connection, which decide what the composer and the prompt card offer.
    func showInput(_ pane: Herd.Pane?, isOnline: Bool) {
        composer.show(pane, isOnline: isOnline)
        prompt.show(pane, isOnline: isOnline)
    }

    /// Applies a pane detail command and ignores every other. `hasPane`: the window shows a pane.
    func perform(_ command: AppCommand, hasPane: Bool) {
        switch command {
        case .send: composer.send()
        case .sendKey(let key): composer.send(key)
        case .answerPrompt(let number): prompt.answer(number)
        case .toggleChanges, .setChangesShown, .toggleSessionFacts, .setSessionFactsShown:
            panels.perform(command, hasPane: hasPane)
        case .copyPath(let path): clipboard.copy(path)
        case .toggleTerminal, .showPanel: layout.perform(command)
        case .setTerminalVisible(let visible): terminal.setVisible(visible)
        default: conversation.perform(command, clipboard: clipboard)
        }
    }

    /// Whether a pane detail command applies now; nil for any other command.
    func isEnabled(_ command: AppCommand, hasPane: Bool) -> Bool? {
        switch command {
        case .send: composer.canSend
        case .sendKey(let key): composer.canSend(key)
        case .answerPrompt: prompt.canAnswer
        case .copyPath, .setTerminalVisible: true
        case .findInConversation, .findNext, .findPrevious:
            layout.detail == .conversation && conversation.isEnabled(command) == true
        default:
            PanePanels.isEnabled(command, hasPane: hasPane)
                ?? layout.isEnabled(command, hasPane: hasPane)
                ?? conversation.isEnabled(command)
        }
    }

    /// Whether a menu item that switches a panel shows a checkmark; nil for any other command.
    func isChecked(_ command: AppCommand) -> Bool? {
        panels.isChecked(command) ?? layout.isChecked(command)
    }
}
