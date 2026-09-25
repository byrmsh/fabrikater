import AppUI
import FabrikaterCore
import SwiftUI

@main
struct FabrikaterApp: App {
    private let log = Log(category: "App")

    init() {
        log.info("launched")
    }

    var body: some Scene {
        WindowGroup("fabrikater") {
            RootView()
        }
        .defaultSize(width: 1100, height: 720)
    }
}
