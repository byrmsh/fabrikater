import AppKit
import AppModel
import FabrikaterCore
import Foundation

/// Hands a link to the app that claims its scheme, such as VS Code for `vscode://`.
@MainActor
final class WorkspaceURLOpener: URLOpener {
    private let log = Log(category: "App")

    func open(_ url: URL) {
        if !NSWorkspace.shared.open(url) {
            log.error("no app opens \(url.scheme ?? "this") links")
        }
    }
}
