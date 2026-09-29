import FabrikaterCore
import Foundation

/// A panel that sits beside a pane's conversation or terminal and can be shown, hidden and moved.
public enum InfoPanel: String, Codable, CodingKeyRepresentable, CaseIterable, Sendable {
    /// The agent's latest todo plan (B10).
    case plan
    /// The files the session changed (B12).
    case changes
    /// The session's model, folder, branch, start and context use (B11).
    case facts

    public var title: String {
        switch self {
        case .plan: "Plan"
        case .changes: "Changes"
        case .facts: "Session Info"
        }
    }

    /// The View menu's submenu that arranges this panel.
    public var menuTitle: String { "\(title) Panel" }

    /// The panel header's menu item that hides it.
    public var hideTitle: String { "Hide \(title)" }
}

/// Where a panel sits in a window.
public enum PanelDock: String, Codable, CaseIterable, Sendable {
    /// A strip above the conversation or terminal.
    case top
    /// A column between the sidebar and the conversation.
    case leading
    /// The inspector column on the right.
    case trailing

    public var title: String {
        switch self {
        case .top: "Above the Conversation"
        case .leading: "On the Left"
        case .trailing: "On the Right"
        }
    }
}

/// Which panels a window shows, where each sits and in what order (`.claude/skills/macos-design`, Rule 2). Each window
/// keeps its own; the last change is saved, and new windows and the next launch start from it.
public struct PanelLayout: Codable, Equatable, Sendable {
    /// Every panel once, top to bottom within each dock.
    public private(set) var order: [InfoPanel]
    public private(set) var docks: [InfoPanel: PanelDock]
    public private(set) var shown: Set<InfoPanel>

    /// The plan above the conversation, changes and session info on the right, hidden.
    public static let standard = PanelLayout(
        order: [.plan, .changes, .facts], docks: [.plan: .top, .changes: .trailing, .facts: .trailing], shown: [.plan])

    public func isShown(_ panel: InfoPanel) -> Bool { shown.contains(panel) }

    public func dock(of panel: InfoPanel) -> PanelDock { docks[panel] ?? Self.standard.docks[panel] ?? .trailing }

    /// The shown panels in `dock`, top to bottom.
    public func panels(in dock: PanelDock) -> [InfoPanel] {
        order.filter { isShown($0) && self.dock(of: $0) == dock }
    }

    /// The shown panel in the same dock just above or below `panel`, which moving it swaps with.
    private func neighbour(of panel: InfoPanel, by step: Int) -> InfoPanel? {
        let column = panels(in: dock(of: panel))
        guard let index = column.firstIndex(of: panel), column.indices.contains(index + step) else { return nil }
        return column[index + step]
    }

    /// Whether `command` would change the layout.
    func canApply(_ command: AppCommand) -> Bool {
        var changed = self
        changed.apply(command)
        return changed != self
    }

    /// Applies a panel command and ignores every other.
    mutating func apply(_ command: AppCommand) {
        switch command {
        case .togglePanel(let panel):
            if shown.remove(panel) == nil { shown.insert(panel) }
        case .hidePanels(let dock):
            shown = shown.filter { self.dock(of: $0) != dock }
        case .movePanel(let panel, let dock):
            guard self.dock(of: panel) != dock || !isShown(panel) else { return }
            // Last in its new dock.
            order.removeAll { $0 == panel }
            order.append(panel)
            docks[panel] = dock
            shown.insert(panel)
        case .movePanelUp(let panel): swap(panel, neighbour(of: panel, by: -1))
        case .movePanelDown(let panel): swap(panel, neighbour(of: panel, by: 1))
        case .resetPanels: self = .standard
        default: break
        }
    }

    private mutating func swap(_ panel: InfoPanel, _ other: InfoPanel?) {
        guard let other, let from = order.firstIndex(of: panel), let to = order.firstIndex(of: other) else { return }
        order.swapAt(from, to)
    }

    /// Whether a panel command's menu item shows a checkmark; nil for any other command.
    func isChecked(_ command: AppCommand) -> Bool? {
        switch command {
        case .togglePanel(let panel): isShown(panel)
        case .movePanel(let panel, let dock): isShown(panel) && self.dock(of: panel) == dock
        default: nil
        }
    }

    /// Whether `command` is a panel command.
    static func handles(_ command: AppCommand) -> Bool {
        switch command {
        case .togglePanel, .hidePanels, .movePanel, .movePanelUp, .movePanelDown, .resetPanels: true
        default: false
        }
    }

    /// A saved layout from an older or newer version: every panel exactly once, in a known dock.
    func normalized() -> PanelLayout {
        var seen = Set<InfoPanel>()
        let known = order.filter { seen.insert($0).inserted }
        return PanelLayout(
            order: known + InfoPanel.allCases.filter { !seen.contains($0) },
            docks: Dictionary(uniqueKeysWithValues: InfoPanel.allCases.map { ($0, dock(of: $0)) }),
            shown: shown)
    }
}

/// Where the last `PanelLayout` is kept between launches.
@MainActor
public protocol PanelLayoutStorage: AnyObject {
    func load() -> PanelLayout
    func save(_ layout: PanelLayout)
}

/// A layout that lasts until the app quits: the default for tests.
@MainActor
public final class InMemoryPanelLayoutStorage: PanelLayoutStorage {
    private var layout: PanelLayout

    public init(_ layout: PanelLayout = .standard) {
        self.layout = layout
    }

    public func load() -> PanelLayout { layout }
    public func save(_ layout: PanelLayout) { self.layout = layout }
}

/// The layout as JSON under one `UserDefaults` key; one that does not decode is the standard layout.
@MainActor
public final class UserDefaultsPanelLayoutStorage: PanelLayoutStorage {
    private let defaults: UserDefaults
    private let key: String
    private let log = Log(category: "AppModel")

    public init(defaults: UserDefaults, key: String = "panelLayout") {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> PanelLayout {
        guard let data = defaults.data(forKey: key) else { return .standard }
        do {
            return try JSONDecoder().decode(PanelLayout.self, from: data).normalized()
        } catch {
            log.error("the saved panel layout does not decode; using the standard one")
            return .standard
        }
    }

    public func save(_ layout: PanelLayout) {
        guard let data = try? JSONEncoder().encode(layout) else { return }
        defaults.set(data, forKey: key)
    }
}
