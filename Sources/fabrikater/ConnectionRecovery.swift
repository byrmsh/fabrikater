import AppKit
import AppModel
import FabrikaterCore
import HostKit
import Network

/// After the Mac wakes or moves to another network, the shared ssh connection is usually dead, but ssh takes up to
/// 45 s to notice and every feed riding on it hangs until then. Dropping it and ending every feed's backoff brings the
/// host back within seconds.
@MainActor
enum ConnectionRecovery {
    /// - Parameter usesSSH: false for fixture runs, which have no connection to drop.
    static func start(session: HostSession, reconnect: ReconnectPolicy, usesSSH: Bool) {
        let log = Log(category: "App")
        let recover: @MainActor @Sendable (String) -> Void = { reason in
            log.info("\(reason); reconnecting")
            let host = usesSSH ? HostAlias(session.preferences.connectedHost) : nil
            Task {
                if let host {
                    await SSHRunner(host: host).closeSharedConnection()
                }
                reconnect.retryNow()
            }
        }
        _ = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { recover("woke from sleep") }
        }
        Task {
            for await _ in networkChanges(in: networkPaths()) {
                recover("network changed")
            }
        }
    }

    /// The system's network path updates, from `NWPathMonitor`.
    private static func networkPaths() -> AsyncStream<NetworkPath> {
        AsyncStream { continuation in
            let monitor = Task {
                for await path in NWPathMonitor() {
                    continuation.yield(
                        NetworkPath(
                            isSatisfied: path.status == .satisfied,
                            interfaces: path.availableInterfaces.map(\.name),
                            gateways: path.gateways.map { "\($0)" }))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in monitor.cancel() }
        }
    }
}
