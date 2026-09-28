# fabrikater: macOS tooling research (2026-09-24)

Research for a native SwiftUI macOS app built with only Apple's Command Line Tools (CLT) and SwiftPM, talking to the Linux host `arch` over SSH. Versions were checked on 2026-09-24 against Apple's software-update catalog, xcodereleases.com and the GitHub API. Claims marked **[unverified]** come from memory or a single secondhand source.

## Recommended stack

Toolchain: Command Line Tools for Xcode 27.0 (Swift 6.4, macOS 27.0 SDK), built with `swift build`, packaged into a `.app` by a shell script, ad-hoc signed with `codesign --force --sign - fabrikater.app`. The most important finding: under CLT 27, SwiftUI's `@State` no longer compiles (see section 1). The fix is to declare `typealias ViewState = SwiftUI.State` and write `@ViewState` everywhere. Also avoid `#Preview`, SwiftData `@Model` and `@Entry`.

Deployment target: `.macOS(.v15)`. CLT 27 itself only installs on macOS 26.6 or later, so the build Mac is already newer than that.

SSH: spawn `/usr/bin/ssh` through `Process`. One long-lived `ssh -T arch <remote helper or tail command>` carries events and streams. A ControlMaster/ControlPersist master connection makes the one-off commands cheap. Do not use a Swift SSH library. Build without the App Sandbox and distribute outside the App Store.

Terminal view: SwiftTerm (MIT), pinned to v1.11.2 since M4, the last release before its Metal shader, which the Command Line Tools cannot compile ([decisions/0013](decisions/0013-swiftterm-terminal-view.md)), fed bytes with `TerminalView.feed(byteArray:)`. No PTY (pseudo-terminal) is needed.

Markdown: our own block parser (`AppModel/MarkdownBlocks.swift`) and view, not Textual, which does not build under the Command Line Tools ([decisions/0011](decisions/0011-own-markdown-blocks.md), section 4).

Extras: `UNUserNotificationCenter` works once the app is a real bundle with a `CFBundleIdentifier`. The Keychain isn't needed. A `MenuBarExtra` is cheap to add.

## 1. Building with only the Command Line Tools

The current package is "Command Line Tools for Xcode 27.0". It entered Apple's software-update catalog on 2026-09-09, alongside Xcode 27.0 (released 2026-09-14, Swift 6.4, macOS SDK 27.0). Its distribution file allows macOS 26.6 up to but not including 28.0. The download is about 532 MB: `CLTools_Executables` is 350 MB, the two SDK packages are 62 and 71 MB, and SwiftBackDeploy is 49 MB. Installed, it takes about 3.5 GB (1.7 GB of executables, 0.75 plus 0.9 GB of SDKs, 0.2 GB of back-deploy libraries). Macs still on macOS 26.2 to 26.5 get "Command Line Tools for Xcode 26.6" instead (posted 2026-06-26, about 943 MB download).

CLT ships full macOS SDKs, so SwiftUI, AppKit, WebKit and UserNotifications all compile. `swift build` is included, and in Swift 6.4 SwiftPM builds with the new "swiftbuild" engine by default. There are two SDKs: `ls /Library/Developer/CommandLineTools/SDKs` on the CI runner's CLT 27.0 lists `MacOSX26.5.sdk` and `MacOSX27.0.sdk` (plus the `MacOSX.sdk`, `MacOSX26.sdk` and `MacOSX27.sdk` symlinks) (**verified** 2026-09-25).

Things that break without Xcode:

- **`@State` in the macOS 27 SDK.** The SDK now declares `State` twice, as a property wrapper and as an attached macro. The macro wins name lookup, and its compiler plugin, `libSwiftUIMacros.dylib`, ships only inside Xcode.app. CLT includes only `libObservationMacros` and `libSwiftMacros`. The error is `external macro implementation type 'SwiftUIMacros.StateMacro' could not be found`. The Xcode 27 macro behaviour does not depend on the deployment target, so lowering the target doesn't avoid it. Several projects hit this in September 2026: Advisior/local-stt#35, drumih/turbo-fieldfare#185, Revelation-Hosting/MacSportsBar PR #5, ExxtraV/Sable PR #21 (merged 2026-09-23). There are three workarounds. (a) `typealias ViewState = SwiftUI.State`: no macro has that name, so lookup falls back to the property wrapper, and `$binding` syntax still works. (**Verified** 2026-09-25: `AppUI` with `@ViewState` and a `$columnVisibility` binding compiles under CLT 27.0 in CI.) MacSportsBar uses this. (b) Pin `SDKROOT` to the 26.x SDK, as Sable does. (c) Install Xcode. Use (a). The `@Observable` macro keeps working, because its plugin ships in CLT.
- **Other Apple macros.** Any macro whose plugin lives in the Xcode-only platform directory fails the same way. `FoundationModelsMacros` (`@Generable`) is confirmed missing in cjpais/Handy#1448. SwiftData's `@Model`, SwiftUI's `#Preview`, `@Previewable` and `@Entry` are very likely missing too **[unverified: inferred from the same plugin layout]**. Previews need Xcode regardless. Store app state in plain Codable types or JSON files, not SwiftData.
- **swiftbuild bugs.** swiftbuild adds search paths that don't exist under CLT (swiftlang/swift-package-manager#10557, opened 2026-09-18). They cause linker warnings only (**verified**: `ld: warning: search path '/Library/Developer/CommandLineTools/Developer/Library/Frameworks' not found` on every link). They aren't compiler warnings, so `-warnings-as-errors` does not trip on them. Sable also hit an SDKSettings.plist failure. For either problem, `swift build --build-system native` is the fallback.
- **Tests.** XCTest is not in CLT. swift-testing is, at `/Library/Developer/CommandLineTools/Library/Developer/Frameworks/Testing.framework`, but a bare `swift test` fails (mixutin/Mallow#10). **Verified on CLT 27.0 on the GitHub `xcode-27` runner, 2026-09-25:** swiftbuild finds the framework by itself, but not the macro plugin at `usr/lib/swift/host/plugins/testing/libTestingMacros.dylib`, so every `@Test` fails with "plugin for module 'TestingMacros' not found". `scripts/check.sh` passes `-Xswiftc -plugin-path -Xswiftc <CLT>/usr/lib/swift/host/plugins/testing`, plus `-F` and rpaths to the framework and to `Library/Developer/usr/lib` for the native engine and for run time, to both `swift build --build-tests` and `swift test`. The same flags work on the user's Mac (CLT 27.0, Swift 6.4, 2026-09-25): `scripts/check.sh` passes there. Write the tests with swift-testing and run them through `scripts/check.sh`.
- **Asset catalogs and `actool`.** These are Xcode-only, so there is no `.xcassets`, and no Icon Composer `.icon` for the macOS 26 Liquid Glass style. Instead, make a 1024 px PNG, use `sips` to write the sizes an `.iconset` needs, run `iconutil -c icns`, put the result in `Contents/Resources` and set `CFBundleIconFile`. `sips`, `iconutil` and `codesign` are part of base macOS, not CLT **[unverified, but long-standing]**. On macOS 26, a legacy `.icns` may be drawn inside a grey rounded-square frame **[unverified]**.

To package a `.app`, lay it out as `fabrikater.app/Contents/{MacOS/fabrikater, Info.plist, Resources/}`. Info.plist needs:

- `CFBundleExecutable`, `CFBundleIdentifier` (e.g. `sh.bayram.fabrikater`), `CFBundleName`
- `CFBundlePackageType=APPL`, `CFBundleShortVersionString`, `CFBundleVersion`
- `LSMinimumSystemVersion=15.0`, `NSHighResolutionCapable=true`, `CFBundleIconFile`
- `LSApplicationCategoryType` (optional); `LSUIElement=true` only if the app should run from the menu bar with no Dock icon

The SwiftUI `App` lifecycle does not need `NSPrincipalClass`. Also copy every `*.bundle` from the build directory into `Contents/Resources`, or `Bundle.module` crashes at launch (VitalyArt/Aula-F75-Max-Driver#9). SwiftTerm ships a resource bundle. Run `codesign --force --deep --sign - fabrikater.app` last. The linker already ad-hoc signs the arm64 binary, but after you add Info.plist and resources the whole bundle has to be re-signed.

Gatekeeper only checks files carrying the `com.apple.quarantine` attribute, which browsers, AirDrop and similar tools add. An app built locally doesn't get it, so it launches without a prompt. If the `.app` ever travels by download or AirDrop, clear the attribute with `xattr -dr com.apple.quarantine` or allow it under System Settings > Privacy & Security. One side effect of ad-hoc signing is that every rebuild changes the code hash, so TCC (Transparency, Consent and Control, the macOS privacy-permission database) forgets grants such as Accessibility. That rarely matters here, because notification permission is keyed on the bundle id.

Templates and write-ups: tqbf/swiftui-app (SwiftPM plus `build.sh`, ad-hoc signing via `make run`), eudoxia0/swiftui-without-xcode, unisn-g/xcodeless_swiftui (Make), objc.io "SwiftUI without an Xcode project" (2020), and the octavore.com post "let's build a macos app from the command line!" (May 2026).

## 2. SSH from the app

Option (a) is to spawn `/usr/bin/ssh` with `Process`. It uses the user's `~/.ssh/config` (the `arch` alias, `ProxyJump`, `IdentityFile`, `UseKeychain`), `known_hosts` and ssh-agent exactly as the terminal does. On macOS, launchd sets `SSH_AUTH_SOCK` for GUI apps too **[unverified for launches from Finder]**.

Configure multiplexing in the command line or in `~/.ssh/config`:

- `ControlMaster=auto`, `ControlPath=~/.ssh/cm-%C` (`%C` keeps the socket path under the 104-byte limit), `ControlPersist=10m`
- `ServerAliveInterval=15`, `BatchMode=yes` (so a missing key fails instead of hanging on a password prompt), and `-T`

With the master connection up, each extra command costs about one round trip (~140 ms) plus remote exec time, instead of a full TCP and key exchange handshake (roughly 3 to 4 round trips). Also run one long-lived `ssh -T arch 'herdr … --follow'` or `tail -F file.jsonl`, and read its stdout line by line with `FileHandle.bytes.lines`. Always call ssh by absolute path, because GUI apps don't inherit a shell `PATH`. A better long-term design is a small remote helper speaking newline-delimited JSON over a single ssh stdin/stdout pair: requests are pipelined, so latency stays at one round trip with no per-command process spawn on either end.

Option (b) is a Swift SSH library. Citadel (MIT, v0.12.1, 2026-04-04) is built on apple/swift-nio-ssh (Apache-2.0, v0.15.0, 2026-07-28). It handles ed25519 keys, OpenSSH private-key parsing and jump hosts. It does not read `~/.ssh/config`, `known_hosts` or ssh-agent: the README shows only `hostKeyValidator: .acceptAnything()`. libssh2 wrappers such as Shout or NMSSH are old and also skip the config file **[maintenance status unverified]**. With either, you'd be reimplementing the user's SSH setup and host-key checking.

The App Sandbox blocks spawning `/usr/bin/ssh` against `~/.ssh` and reading the user's config. Build without the sandbox, sign ad-hoc or with Developer ID, and skip the App Store. Choose option (a).

## 3. Terminal view

SwiftTerm (migueldeicaza/SwiftTerm) is MIT-licensed, with about 1.7k stars. The last release is v1.20.0 (2026-08-18), described as "one last release before we land the breaking changes". Main is active, with commits through 2026-09-23, and its manifest now needs swift-tools 6.2 (fine with Swift 6.4). v1.20.0 supports macOS 13 and later (macOS 11 when its benchmark target is disabled). It is a SwiftPM package. The AppKit `TerminalView` (an NSView) is transport-agnostic: `public func feed(byteArray: ArraySlice<UInt8>)` and `feed(text: String)` push any bytes, including ANSI escapes, with no PTY, and a `TerminalViewDelegate` receives keystrokes and resize events. `LocalProcessTerminalView` is only the local-PTY convenience subclass.

Features: scrollback, selection, OSC 8 hyperlinks, an optional Metal renderer, and BiDi. A benchmark target exists in the repo **[no published throughput numbers checked]**. Wrap it in an `NSViewRepresentable`. To display snapshots of an agent pane's screen, resize the terminal to the pane's columns and rows, then feed a clear-screen and cursor-home sequence (`ESC[H ESC[2J`) followed by the snapshot, or use the SwiftTerm API to reset the terminal. If herdr can stream the raw pane output, feed it incrementally instead. Pin a version, because breaking changes are in progress on main.

Alternatives: for a read-only colour snapshot, a roughly 150-line SGR parser (SGR is the ANSI escape family that sets colour and text style) producing an `AttributedString` in a monospaced `Text` or `NSTextView` is lighter and has no dependency. Ghostty's embeddable library (libghostty) is another option **[its Swift embedding status is unverified]**.

## 4. Markdown for long, growing transcripts

gonzalezreal/swift-markdown-ui (MIT) is officially in maintenance mode. Its README says: "New development is happening in Textual, a SwiftUI-native text rendering engine that evolved from the ideas and lessons learned in MarkdownUI." Its last release is 2.4.1 (2024-10-13).

Textual (MIT) is at 0.5.0 (2026-06-15) and needs macOS 15. It parses Markdown with Foundation's `AttributedString` parser, and supports native text selection, code blocks with syntax highlighting (Prism grammars), tables (link interaction in tables was added in 0.5.0), lists, math and images. It is pre-1.0, so expect API churn. **It does not build under CLT 27** (verified in its sources at 0.5.0, 2026-09-28): it uses the State property wrapper by its SwiftUI name, `@Entry` and `#Preview`, whose macros ship only with Xcode (section 1).

Foundation's `AttributedString(markdown:)` parses block structure only as `presentationIntent` attributes. SwiftUI `Text` renders inline styling only, so tables, code blocks and lists need your own layout. swiftlang/swift-markdown (Apache-2.0, v0.9.0, 2026-09-21) gives a full cmark-gfm syntax tree, but then you write the renderer yourself.

A `WKWebView` running markdown-it or marked plus highlight.js handles the whole transcript. New messages are appended through `evaluateJavaScript`, text selection works across messages, and the web engine handles 10k+ blocks well. The costs are a web view, bridging code and a non-native look.

For performance, don't put a long transcript in a `ScrollView` with a `LazyVStack`. Lazy stacks with variable-height rows estimate heights, so scroll position jumps and memory grows. On macOS, SwiftUI `List` is backed by `NSTableView` and recycles rows. At WWDC25 Apple claimed much faster large-list loading and updates on macOS 26 **[figures unverified]**. For the most control, use an `NSTableView` with `NSHostingView` cells and cache row heights per message id. Only the last message changes while it streams, so parse and cache finished messages once.

Chosen: our own block parser in `AppModel` and a SwiftUI view per block, with Foundation's inline parser for emphasis, code and links ([decisions/0011](decisions/0011-own-markdown-blocks.md)). Move to a single `WKWebView` transcript if profiling shows stalls past a few thousand messages.

## 5. Other points

- **Notifications.** `UNUserNotificationCenter.current()` asserts with "bundleProxyForCurrentProcess is nil" in an unbundled executable, including `swift run`. Inside the `.app` with a `CFBundleIdentifier` it works when ad-hoc signed, because the grant is keyed on the bundle id. Call `requestAuthorization` at first launch.
- **Keychain.** Not needed: ssh reads the keys, and the agent or `UseKeychain` handles passphrases.
- **Menu bar.** SwiftUI's `MenuBarExtra` with `.menuBarExtraStyle(.window)` (macOS 13 and later) can show agent status and a quick-prompt field next to the main `WindowGroup`. Add `LSUIElement` only for a menu-bar-only mode.
- **Local Network privacy.** Since macOS 15, apps need permission to reach LAN addresses, and the prompt is attributed to the app that spawned ssh. It only applies if `arch` resolves to a LAN address, not a Tailscale or public one **[unverified for child processes]**.
- **Background activity.** Handle wake from sleep by restarting the streaming ssh when it exits (`terminationHandler`) with backoff. A ControlMaster socket survives sleep poorly **[unverified]**, so `ServerAliveInterval` plus reconnect logic matters more than persistence.

## Sources

- Apple software-update catalog (swscan.apple.com, CLT 27.0 product 082-83364 and CLT 26.6 product 140-17812); xcodereleases.com/data.json
- https://github.com/Advisior/local-stt/issues/35 · https://github.com/drumih/turbo-fieldfare/issues/185 · https://github.com/Revelation-Hosting/MacSportsBar/pull/5 · https://github.com/ExxtraV/Sable/pull/21 · https://github.com/cjpais/Handy/issues/1448 · https://blakecrosley.com/blog/state-macro-xcode-27
- https://github.com/swiftlang/swift-package-manager/issues/10557 · https://github.com/mixutin/Mallow/issues/10 · https://github.com/VitalyArt/Aula-F75-Max-Driver/issues/9
- https://github.com/tqbf/swiftui-app · https://github.com/eudoxia0/swiftui-without-xcode · https://github.com/unisn-g/xcodeless_swiftui · https://www.objc.io/blog/2020/05/19/swiftui-without-an-xcodeproj/ · https://etc.octavore.com/2026/05/macos-app-without-xcode/
- https://github.com/migueldeicaza/SwiftTerm · https://github.com/gonzalezreal/swift-markdown-ui · https://github.com/gonzalezreal/textual · https://github.com/swiftlang/swift-markdown · https://github.com/orlandos-nl/Citadel · https://github.com/apple/swift-nio-ssh
- https://developer.apple.com/forums/thread/649583 (UNUserNotificationCenter bundle-proxy crash)
