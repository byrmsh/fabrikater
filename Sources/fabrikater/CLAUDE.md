# fabrikater (executable)

The `App` and the single composition root. macOS only.

- This is the only place that constructs services and stores and decides between real and replay implementations: `ReplayRunner` over `FABRIKATER_FIXTURES=<dir>`, else `SSHRunner` to `FABRIKATER_HOST`, else the host saved in Settings (default `arch`). No singletons anywhere else. Everything tied to a host is built in the one closure handed to `HostSession`, which calls it again when Settings connects to another host; app-wide pieces (preferences, the notifier, the send policy, the `ReconnectPolicy`) are built once outside it. `WakeRecovery` drops the shared ssh connection and calls `retryNow()` when the Mac wakes.
- Keep it to wiring: no logic worth testing lives here. `SystemNotifier` posts `PaneAlert`s through `UNUserNotificationCenter` and routes a click back to `AppStore`; fixture runs and a run without a bundle id get none.
- Scenes: one main `WindowGroup` titled "fabrikater" (docs/design.md), with `PaneCommands` from `AppUI` for the menu bar. a `Settings` scene with `SettingsView` (⌘,). `NeedsYouMenuBar` from `AppUI`, the menu bar item. The main `WindowGroup` has the id `MainWindow.sceneID`, which the menu bar item uses to find or reopen it.
- The bundle is assembled by `scripts/bundle.sh` from `Bundle/Info.plist` (bundle id `sh.bayram.fabrikater`, macOS 15). Keep the plist and the script in step.
