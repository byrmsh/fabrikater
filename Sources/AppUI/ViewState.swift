import SwiftUI

/// SwiftUI's `State` property wrapper under a name the macOS 27 SDK does not also declare as a macro.
///
/// That SDK resolves the plain spelling to a macro whose plugin ships only with Xcode, so a Command Line Tools
/// build fails on it (docs/macos-tooling.md section 1). Views write `@ViewState`; `scripts/check.sh` enforces it.
typealias ViewState = SwiftUI.State
