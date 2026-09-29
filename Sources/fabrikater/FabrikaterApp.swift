import AppKit
import AppModel
import AppUI
import FabrikaterCore
import Foundation
import HerdrKit
import HostKit
import SwiftUI
import TranscriptKit

@main
struct FabrikaterApp: App {
    private let session: HostSession

    /// The composition root: the only place that builds services (docs/structure.md, "Dependency rules").
    init() {
        let log = Log(category: "App")
        let environment = ProcessInfo.processInfo.environment
        // Fixture runs keep their notes and settings apart, so a demo or an e2e flow never touches the real ones.
        let fixtures = environment["FABRIKATER_FIXTURES"]
        let defaults =
            fixtures == nil
            ? UserDefaults.standard : UserDefaults(suiteName: "sh.bayram.fabrikater.fixtures") ?? .standard
        let preferenceStorage = UserDefaultsPreferencesStorage(defaults: defaults)
        let alias = environment["FABRIKATER_HOST"] ?? preferenceStorage.load().host ?? Preferences.defaultHost
        let host = HostAlias(alias) ?? HostAlias(Preferences.defaultHost)!
        if host.rawValue != alias {
            log.error("the host is not a valid ssh alias; using arch")
        }
        let preferences = PreferencesStore(
            storage: preferenceStorage, connectedHost: host.rawValue,
            hostIsOverridden: environment["FABRIKATER_HOST"] != nil, isValidHost: { HostAlias($0) != nil })
        #if DEBUG
            let isDebugBuild = true
        #else
            let isDebugBuild = false
        #endif
        // Fixture runs stay silent; the notification centre needs a bundle id, which `swift run` does not have.
        let notifier =
            fixtures == nil && Bundle.main.bundleIdentifier != nil ? SystemNotifier() : nil
        let policy = SendPolicy(environment: environment, isDebugBuild: isDebugBuild)
        // Everything tied to a host, built again when Settings connects to another one.
        session = HostSession(preferences: preferences) { alias in
            let host = HostAlias(alias) ?? HostAlias(Preferences.defaultHost)!
            let runner: any HostCommandRunner
            if let fixtures {
                log.info("replaying fixtures")
                runner = ReplayRunner(directory: URL(filePath: fixtures))
            } else {
                runner = SSHRunner(host: host)
            }
            let client = HerdrClient(runner: runner)
            let fresh: @Sendable () async throws -> Herd = { try await client.snapshot() }
            return AppStore(
                herdUpdates: HerdFeed(service: client).updates(),
                transcripts: HostTranscriptService(runner: runner),
                history: HostTranscriptService(runner: runner),
                control: PolicedControl(SendGuard(client, reader: client), policy: policy, fresh: fresh),
                screens: client,
                answers: PolicedControl(client, policy: policy, fresh: fresh),
                terminals: client,
                notes: UserDefaultsPaneNotesStore(defaults: defaults),
                drafts: UserDefaultsDraftStorage(defaults: defaults),
                panelLayouts: UserDefaultsPanelLayoutStorage(defaults: defaults),
                clipboard: PasteboardClipboard(),
                opener: WorkspaceURLOpener(),
                host: host.rawValue,
                notifier: notifier ?? RecordingNotifier(),
                isAppActive: { NSApplication.shared.isActive },
                preferences: preferences
            )
        }
        let session = session
        notifier?.onOpen = { session.store.perform(.selectPane($0)) }
        log.info("launched")
    }

    var body: some Scene {
        WindowGroup("fabrikater", id: MainWindow.sceneID) {
            MainWindow(session: session)
        }
        .defaultSize(width: 1100, height: 720)
        .windowToolbarStyle(.unified)
        .commands {
            ViewCommands(session: session)
            PaneCommands(session: session)
            FindCommands(session: session)
        }
        WindowGroup("Pane", for: PaneID.self) { $id in
            if let id {
                PaneWindowView(session: session, paneID: id)
            }
        }
        .defaultSize(width: 720, height: 720)
        .windowToolbarStyle(.unified)
        WindowGroup("Session", for: SessionWindowID.self) { $id in
            if let id {
                SessionWindowView(session: session, id: id)
            }
        }
        .defaultSize(width: 720, height: 720)
        .windowToolbarStyle(.unified)
        Settings {
            SettingsView(preferences: session.preferences)
        }
        NeedsYouMenuBar(session: session)
    }
}
