import Observation

/// The app's connection to one host at a time. Everything tied to the host (the herd, the conversations, the pane and
/// past session windows) lives in one `AppStore`, which the composition root builds for a host alias; connecting to
/// another host from Settings closes that store and builds the next one. The preferences, drafts and pane notes outlive
/// it.
@MainActor
@Observable
public final class HostSession {
    /// The store for the host connected to now.
    public private(set) var store: AppStore
    public let preferences: PreferencesStore
    @ObservationIgnored private let makeStore: (String) -> AppStore

    /// - Parameter makeStore: builds the services and the store for an ssh alias, given `preferences.connectedHost`
    ///   first.
    public init(preferences: PreferencesStore, makeStore: @escaping (String) -> AppStore) {
        self.preferences = preferences
        self.makeStore = makeStore
        store = makeStore(preferences.connectedHost)
        preferences.onConnect = { [weak self] host in self?.connect(to: host) }
    }

    private func connect(to host: String) {
        store.close()
        store = makeStore(host)
    }
}
