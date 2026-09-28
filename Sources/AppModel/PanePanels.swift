/// The panels a window shows beside a pane's conversation: the changes inspector (B12) and the session facts popover
/// (B11). The main window and each pane window keep their own.
public struct PanePanels: Equatable, Sendable {
    public private(set) var isShowingChanges = false
    /// The popover on the toolbar's status item is open.
    public private(set) var isShowingSessionFacts = false

    /// Applies a panel command and ignores every other. `hasPane`: the window shows a pane, whose status the popover
    /// hangs from.
    mutating func perform(_ command: AppCommand, hasPane: Bool) {
        switch command {
        case .toggleChanges: isShowingChanges.toggle()
        case .setChangesShown(let shown): isShowingChanges = shown
        case .toggleSessionFacts: isShowingSessionFacts = hasPane && !isShowingSessionFacts
        case .setSessionFactsShown(let shown): isShowingSessionFacts = hasPane && shown
        default: break
        }
    }

    /// Whether a panel command applies now; nil for any other command.
    static func isEnabled(_ command: AppCommand, hasPane: Bool) -> Bool? {
        switch command {
        case .toggleChanges, .toggleSessionFacts: hasPane
        case .setChangesShown, .setSessionFactsShown: true
        default: nil
        }
    }

    /// The checkmark of a panel command that switches a panel; nil for any other command.
    func isChecked(_ command: AppCommand) -> Bool? {
        switch command {
        case .toggleChanges: isShowingChanges
        default: nil
        }
    }

    /// Closes the popover once the window shows no pane.
    mutating func losePane() {
        isShowingSessionFacts = false
    }
}
