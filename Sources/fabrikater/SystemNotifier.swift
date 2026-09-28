import AppKit
import AppModel
import FabrikaterCore
import Foundation
import UserNotifications

/// The `userInfo` key holding the alert's pane id.
private let paneKey = "pane"

/// Posts pane alerts through the notification centre; clicking one brings the app forward and selects its pane.
/// Asks for permission the first time it posts, not at launch.
@MainActor
final class SystemNotifier: NSObject, Notifier, UNUserNotificationCenterDelegate {
    /// Called with the pane of a clicked notification.
    var onOpen: (PaneID) -> Void = { _ in }
    private let log = Log(category: "App")

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func post(_ alert: PaneAlert) {
        Task { [log] in
            do {
                try await Self.deliver(alert, log: log)
            } catch {
                log.error("notification failed: \(error.localizedDescription)")
            }
        }
    }

    /// Builds and adds the notification off the main actor, where the notification centre's types live.
    private nonisolated static func deliver(_ alert: PaneAlert, log: Log) async throws {
        let center = UNUserNotificationCenter.current()
        guard try await center.requestAuthorization(options: [.alert, .sound]) else {
            log.info("notifications are turned off for fabrikater")
            return
        }
        let content = UNMutableNotificationContent()
        content.title = alert.title
        content.subtitle = alert.subtitle
        content.body = alert.body
        content.sound = alert.playsSound ? .default : nil
        content.threadIdentifier = alert.paneID.rawValue
        content.userInfo = [paneKey: alert.paneID.rawValue]
        try await center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
    ) async {
        guard let raw = response.notification.request.content.userInfo[paneKey] as? String, let id = PaneID(raw)
        else { return }
        await open(id)
    }

    /// Alerts show while the app is frontmost too: the rule already leaves out the pane being looked at.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    private func open(_ id: PaneID) {
        NSApp.activate()
        onOpen(id)
    }
}
