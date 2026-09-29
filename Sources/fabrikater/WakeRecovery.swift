import AppKit
import AppModel
import FabrikaterCore
import HostKit

/// When the Mac wakes, the shared ssh connection is usually dead, but ssh takes up to 45 s to notice and every feed
/// riding on it hangs until then. Dropping it and ending every feed's backoff brings the host back within seconds.
@MainActor
enum WakeRecovery {
    /// - Parameter usesSSH: false for fixture runs, which have no connection to drop.
    static func start(session: HostSession, reconnect: ReconnectPolicy, usesSSH: Bool) {
        let log = Log(category: "App")
        _ = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                log.info("woke from sleep; reconnecting")
                let host = usesSSH ? HostAlias(session.preferences.connectedHost) : nil
                Task {
                    if let host {
                        await SSHRunner(host: host).closeSharedConnection()
                    }
                    reconnect.retryNow()
                }
            }
        }
    }
}
