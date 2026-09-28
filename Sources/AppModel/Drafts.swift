import FabrikaterCore
import Foundation
import Observation

/// The composer's unsent text per pane, shared by every window's composer and kept between launches (M3).
///
/// An empty draft is dropped rather than stored, so panes that are gone leave nothing behind once their text is
/// cleared or sent.
@MainActor
@Observable
public final class Drafts {
    private var texts: [PaneID: String]
    @ObservationIgnored private let storage: any DraftStorage

    public init(storage: any DraftStorage = InMemoryDraftStorage()) {
        self.storage = storage
        texts = storage.load().filter { !$0.value.isEmpty }
    }

    public subscript(pane: PaneID) -> String {
        get { texts[pane] ?? "" }
        set {
            guard texts[pane, default: ""] != newValue else { return }
            texts[pane] = newValue.isEmpty ? nil : newValue
            storage.save(texts)
        }
    }
}

/// Where `Drafts` are kept between launches.
@MainActor
public protocol DraftStorage: AnyObject {
    func load() -> [PaneID: String]
    func save(_ drafts: [PaneID: String])
}

/// Drafts that last until the app quits: the default for tests.
@MainActor
public final class InMemoryDraftStorage: DraftStorage {
    private var drafts: [PaneID: String]

    public init(_ drafts: [PaneID: String] = [:]) {
        self.drafts = drafts
    }

    public func load() -> [PaneID: String] { drafts }
    public func save(_ drafts: [PaneID: String]) { self.drafts = drafts }
}

/// Drafts kept as a dictionary of pane id to text under one `UserDefaults` key.
@MainActor
public final class UserDefaultsDraftStorage: DraftStorage {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults, key: String = "composerDrafts") {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> [PaneID: String] {
        let stored = defaults.dictionary(forKey: key) as? [String: String] ?? [:]
        return Dictionary(
            stored.compactMap { key, value in PaneID(key).map { ($0, value) } }, uniquingKeysWith: { $1 })
    }

    public func save(_ drafts: [PaneID: String]) {
        defaults.set(Dictionary(drafts.map { ($0.key.rawValue, $0.value) }, uniquingKeysWith: { $1 }), forKey: key)
    }
}
