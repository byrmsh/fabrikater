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
    private let store: AppStore

    /// The composition root: the only place that builds services (docs/structure.md, "Dependency rules").
    init() {
        let log = Log(category: "App")
        let environment = ProcessInfo.processInfo.environment
        let alias = environment["FABRIKATER_HOST"] ?? "arch"
        let host = HostAlias(alias) ?? HostAlias("arch")!
        if host.rawValue != alias {
            log.error("FABRIKATER_HOST is not a valid ssh alias; using arch")
        }
        let runner: any HostCommandRunner
        // Fixture runs keep their notes apart, so a demo or an e2e flow never touches the real pane names.
        var defaults = UserDefaults.standard
        if let fixtures = environment["FABRIKATER_FIXTURES"] {
            log.info("replaying fixtures")
            runner = ReplayRunner(directory: URL(filePath: fixtures))
            defaults = UserDefaults(suiteName: "sh.bayram.fabrikater.fixtures") ?? .standard
        } else {
            runner = SSHRunner(host: host)
        }
        let client = HerdrClient(runner: runner)
        #if DEBUG
            let isDebugBuild = true
        #else
            let isDebugBuild = false
        #endif
        // Fixture runs stay silent; the notification centre needs a bundle id, which `swift run` does not have.
        let notifier =
            environment["FABRIKATER_FIXTURES"] == nil && Bundle.main.bundleIdentifier != nil ? SystemNotifier() : nil
        let policy = SendPolicy(environment: environment, isDebugBuild: isDebugBuild)
        store = AppStore(
            herdUpdates: HerdFeed(service: client).updates(),
            transcripts: HostTranscriptService(runner: runner),
            control: PolicedControl(SendGuard(client, reader: client), policy: policy) { try await client.snapshot() },
            terminals: client,
            notes: UserDefaultsPaneNotesStore(defaults: defaults),
            drafts: UserDefaultsDraftStorage(defaults: defaults),
            clipboard: PasteboardClipboard(),
            opener: WorkspaceURLOpener(),
            host: host.rawValue,
            notifier: notifier ?? RecordingNotifier(),
            isAppActive: { NSApplication.shared.isActive }
        )
        let store = store
        notifier?.onOpen = { store.perform(.selectPane($0)) }
        log.info("launched")
    }

    var body: some Scene {
        WindowGroup("fabrikater") {
            RootView(store: store)
        }
        .defaultSize(width: 1100, height: 720)
        .windowToolbarStyle(.unified)
        .commands {
            ViewCommands(store: store)
            PaneCommands(store: store)
        }
        WindowGroup("Pane", for: PaneID.self) { $id in
            if let id {
                PaneWindowView(store: store, paneID: id)
            }
        }
        .defaultSize(width: 720, height: 720)
        .windowToolbarStyle(.unified)
    }
}
