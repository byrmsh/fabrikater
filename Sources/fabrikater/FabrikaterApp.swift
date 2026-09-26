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
        let runner: any HostCommandRunner
        if let fixtures = environment["FABRIKATER_FIXTURES"] {
            log.info("replaying fixtures")
            runner = ReplayRunner(directory: URL(filePath: fixtures))
        } else {
            let alias = environment["FABRIKATER_HOST"] ?? "arch"
            let host = HostAlias(alias) ?? HostAlias("arch")!
            if host.rawValue != alias {
                log.error("FABRIKATER_HOST is not a valid ssh alias; using arch")
            }
            runner = SSHRunner(host: host)
        }
        let client = HerdrClient(runner: runner)
        #if DEBUG
            let isDebugBuild = true
        #else
            let isDebugBuild = false
        #endif
        let policy = SendPolicy(environment: environment, isDebugBuild: isDebugBuild)
        store = AppStore(
            herdUpdates: HerdFeed(service: client).updates(),
            transcripts: HostTranscriptService(runner: runner),
            control: PolicedControl(SendGuard(client, reader: client), policy: policy) { try await client.snapshot() },
            notes: UserDefaultsPaneNotesStore(defaults: .standard),
            clipboard: PasteboardClipboard()
        )
        log.info("launched")
    }

    var body: some Scene {
        WindowGroup("fabrikater") {
            RootView(store: store)
        }
        .defaultSize(width: 1100, height: 720)
        .windowToolbarStyle(.unified)
        .commands {
            PaneCommands(store: store)
        }
    }
}
