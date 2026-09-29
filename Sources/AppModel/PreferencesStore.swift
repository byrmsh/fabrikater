import Foundation
import Observation

/// The Settings window's state: the saved `Preferences`, and the host field while it is being edited. Connecting to the
/// field's host saves it and hands it to `HostSession`, which replaces everything tied to the old host.
@MainActor
@Observable
public final class PreferencesStore {
    public private(set) var preferences: Preferences
    /// The host field's text, saved as `preferences.host` when it is connected to.
    public private(set) var hostText: String
    /// The alias the app is connected to now.
    public private(set) var connectedHost: String
    /// Told the host to connect to; `HostSession` sets it.
    @ObservationIgnored var onConnect: ((String) -> Void)?
    private let hostIsOverridden: Bool
    private let isValidHost: (String) -> Bool
    private let storage: any PreferencesStorage

    /// - Parameters:
    ///   - connectedHost: the alias this launch uses.
    ///   - hostIsOverridden: whether `FABRIKATER_HOST` chose it, which it does again at every launch.
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
        // The field shows the host connected to, left empty when that is the default.
        hostText = connectedHost == (saved.host ?? Preferences.defaultHost) ? saved.host ?? "" : connectedHost
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
    }

    /// The host field's button, which Return in the field also presses.
    nonisolated public static let connectTitle = "Connect"

    /// The alias the field names, `arch` when it is empty; nil when it is not an alias.
    private var fieldHost: String? {
        let alias = hostText.trimmingCharacters(in: .whitespaces)
        if alias.isEmpty { return Preferences.defaultHost }
        return isValidHost(alias) ? alias : nil
    }

    /// Whether the host field holds text that cannot be saved.
    public var hostIsInvalid: Bool { fieldHost == nil }

    /// Whether Connect would switch hosts: the field names a valid alias other than the one connected.
    public var canConnect: Bool {
        fieldHost.map { $0 != connectedHost } ?? false
    }

    /// Saves the field's host, keeps it for the next launch, and switches the app to it.
    public func connect() {
        guard canConnect, let host = fieldHost else { return }
        let alias = hostText.trimmingCharacters(in: .whitespaces)
        hostText = alias
        set(\.host, to: alias.isEmpty ? nil : alias)
        connectedHost = host
        onConnect?(host)
    }

    /// What the host field's text means for the connection, under the field.
    public var hostNotice: String {
        guard let host = fieldHost else {
            return "Not an ssh alias: use letters, digits, “-”, “.”, “_” or “@”, and don’t start with “-”."
        }
        if host != connectedHost {
            return "Connected to \(connectedHost). Press Return to connect to \(host)."
        }
        if hostIsOverridden {
            return "Connected to \(connectedHost). FABRIKATER_HOST chooses the host each time fabrikater opens."
        }
        return "An alias from ~/.ssh/config. Connected to \(connectedHost)."
    }

    private func save(_ changed: Preferences) {
        guard changed != preferences else { return }
        preferences = changed
        storage.save(changed)
    }
}
