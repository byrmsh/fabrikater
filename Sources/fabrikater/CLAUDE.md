# fabrikater (executable)

The `App` and the single composition root. macOS only.

- This is the only place that constructs services and stores and decides between real and replay implementations (`FABRIKATER_FIXTURES=<dir>`, from M1). No singletons anywhere else.
- Keep it to wiring: no logic worth testing lives here.
- Scenes: one main `WindowGroup` titled "fabrikater" (docs/design.md). Settings and a `MenuBarExtra` come later.
- The bundle is assembled by `scripts/bundle.sh` from `Bundle/Info.plist` (bundle id `sh.bayram.fabrikater`, macOS 15). Keep the plist and the script in step.
