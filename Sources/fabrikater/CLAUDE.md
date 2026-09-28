# fabrikater (executable)

The `App` and the single composition root. macOS only.

- This is the only place that constructs services and stores and decides between real and replay implementations: `ReplayRunner` over `FABRIKATER_FIXTURES=<dir>`, else `SSHRunner` to `FABRIKATER_HOST`, else the host saved in Settings (default `arch`). No singletons anywhere else.
- Keep it to wiring: no logic worth testing lives here. `SystemNotifier` posts `PaneAlert`s through `UNUserNotificationCenter` and routes a click back to `AppStore`; fixture runs and a run without a bundle id get none.
- Scenes: one main `WindowGroup` titled "fabrikater" (docs/design.md), with `PaneCommands` from `AppUI` for the menu bar. a `Settings` scene with `SettingsView` (⌘,). A `MenuBarExtra` comes later.
- The bundle is assembled by `scripts/bundle.sh` from `Bundle/Info.plist` (bundle id `sh.bayram.fabrikater`, macOS 15). Keep the plist and the script in step.
