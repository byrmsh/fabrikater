import Foundation
import Observation

/// The Settings window's state: the saved `Preferences`, and the host field while it is being edited.
@MainActor
@Observable
public final class PreferencesStore {
    public private(set) var preferences: Preferences
    /// The host field's text, saved as `preferences.host` whenever it is a valid alias or empty.
    public private(set) var hostText: String
    /// The alias this launch connected to.
    public let connectedHost: String
    private let hostIsOverridden: Bool
    private let isValidHost: (String) -> Bool
    private let storage: any PreferencesStorage

    /// - Parameters:
    ///   - connectedHost: the alias this launch uses.
    ///   - hostIsOverridden: whether `FABRIKATER_HOST` chose it, so the saved host waits until that is unset.
    ///   - isValidHost: whether text is an alias ssh can be given (`HostAlias`).
    public init(
        storage: any PreferencesStorage = InMemoryPreferencesStorage(),
        connectedHost: String = Preferences.defaultHost,
        hostIsOverridden: Bool = false,
        isValidHost: @escaping (String) -> Bool = { !$0.isEmpty }
    ) {
        self.storage = storage
        self.connectedHost = connectedHost
        self.hostIsOverridden = hostIsOverridden
        self.isValidHost = isValidHost
        let saved = storage.load()
        preferences = saved
        hostText = saved.host ?? ""
    }

    /// The host field's placeholder: what an empty field means.
    public var hostPlaceholder: String { Preferences.defaultHost }

    /// Changes one preference and saves it.
    public func set<Value: Equatable>(_ field: WritableKeyPath<Preferences, Value>, to value: Value) {
        var changed = preferences
        changed[keyPath: field] = value
        save(changed)
    }

    public func setHostText(_ text: String) {
        hostText = text
        let alias = text.trimmingCharacters(in: .whitespaces)
        if alias.isEmpty {
            set(\.host, to: nil)
        } else if isValidHost(alias) {
            set(\.host, to: alias)
        }
    }

    /// Whether the host field holds text that cannot be saved.
    public var hostIsInvalid: Bool {
        let alias = hostText.trimmingCharacters(in: .whitespaces)
        return !alias.isEmpty && !isValidHost(alias)
    }

    /// What the host field's text means for the connection, under the field.
    public var hostNotice: String {
        if hostIsInvalid {
            return "Not an ssh alias: use letters, digits, “-”, “.”, “_” or “@”, and don’t start with “-”."
        }
        if hostIsOverridden {
            return "FABRIKATER_HOST is set, so fabrikater connects to \(connectedHost)."
        }
        let saved = preferences.host ?? Preferences.defaultHost
        if saved != connectedHost {
            return "fabrikater connects to \(saved) the next time it opens."
        }
        return "An alias from ~/.ssh/config. Connected to \(connectedHost)."
    }

    private func save(_ changed: Preferences) {
        guard changed != preferences else { return }
        preferences = changed
        storage.save(changed)
    }
}
