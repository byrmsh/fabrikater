import FabrikaterCore
import Foundation

/// What fabrikater remembers about panes locally. Herdr is never written to.
///
/// Each feature adds only its own field, decoded with a default so older saved notes still load.
public struct PaneNotes: Equatable, Sendable {
    /// Display names that replace Herdr's label (B1). Kept for panes that are gone, in case they come back.
    public var names: [PaneID: String] = [:]
    /// Pinned panes in the order they were pinned (B4). Kept for panes that are gone, in case they come back.
    public var pins: [PaneID] = []
    /// Hidden panes and workspaces, and the View menu's toggles for them (B5).
    public var hiding = Hiding()

    public init(names: [PaneID: String] = [:], pins: [PaneID] = [], hiding: Hiding = Hiding()) {
        self.names = names
        self.pins = pins
        self.hiding = hiding
    }
}

extension PaneNotes: Codable {
    private enum CodingKeys: String, CodingKey {
        case names
        case pins
        case hiding
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let names = try container.decodeIfPresent([String: String].self, forKey: .names) ?? [:]
        self.names = Dictionary(
            names.compactMap { key, value in PaneID(key).map { ($0, value) } }, uniquingKeysWith: { $1 })
        pins = try container.decodeIfPresent([String].self, forKey: .pins)?.compactMap { PaneID($0) } ?? []
        hiding = try container.decodeIfPresent(Hiding.self, forKey: .hiding) ?? Hiding()
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(
            Dictionary(names.map { ($0.key.rawValue, $0.value) }, uniquingKeysWith: { $1 }), forKey: .names)
        try container.encode(pins.map(\.rawValue), forKey: .pins)
        try container.encode(hiding, forKey: .hiding)
    }
}

/// Where `PaneNotes` are kept between launches.
@MainActor
public protocol PaneNotesStore: AnyObject {
    func load() -> PaneNotes
    func save(_ notes: PaneNotes)
}

/// Notes that last until the app quits: the default for tests and fixture runs.
@MainActor
public final class InMemoryPaneNotesStore: PaneNotesStore {
    private var notes: PaneNotes

    public init(_ notes: PaneNotes = PaneNotes()) {
        self.notes = notes
    }

    public func load() -> PaneNotes { notes }
    public func save(_ notes: PaneNotes) { self.notes = notes }
}

/// Notes kept as JSON under one `UserDefaults` key.
@MainActor
public final class UserDefaultsPaneNotesStore: PaneNotesStore {
    private let defaults: UserDefaults
    private let key: String
    private let log = Log(category: "AppModel")

    public init(defaults: UserDefaults, key: String = "paneNotes") {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> PaneNotes {
        guard let data = defaults.data(forKey: key) else { return PaneNotes() }
        do {
            return try JSONDecoder().decode(PaneNotes.self, from: data)
        } catch {
            log.error("pane notes are unreadable; starting empty")
            return PaneNotes()
        }
    }

    public func save(_ notes: PaneNotes) {
        do {
            defaults.set(try JSONEncoder().encode(notes), forKey: key)
        } catch {
            log.error("pane notes could not be encoded")
        }
    }
}
