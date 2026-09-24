# fabrikater

A native macOS SwiftUI app that shows and drives coding agents running in Herdr on the Linux host `archz`, entirely over SSH. Read these before changing anything:

- [docs/architecture.md](docs/architecture.md): where every piece of data comes from and the exact host commands.
- [docs/design.md](docs/design.md): what the app looks like and how it behaves.
- [docs/parsing.md](docs/parsing.md): the session-log and prompt-screen parsing to implement, ported from Collie.
- [docs/milestones.md](docs/milestones.md): the order of work and how each milestone is checked.
- [docs/macos-tooling.md](docs/macos-tooling.md): building without Xcode, and the library choices.

## Build

This Mac has Apple's Command Line Tools, not Xcode. Everything builds with SwiftPM from the terminal.

- `scripts/bundle.sh` builds release, assembles `build/fabrikater.app`, and ad-hoc signs it. `open build/fabrikater.app` runs it.
- `swift build` for a quick compile. If the default build engine fails with SDK or search-path errors, use `swift build --build-system native`.
- Tests use swift-testing (XCTest is not available without Xcode): `swift test`. If it cannot find `Testing.framework`, see macos-tooling.md section 1.
- Never write `@State`. The macOS 27 SDK's `@State` macro needs a plugin that ships only with Xcode. Use `@ViewState`, defined once as `typealias ViewState = SwiftUI.State`. Avoid `#Preview`, `@Previewable`, `@Entry` and SwiftData. `@Observable` works.
- Deployment target macOS 15. No App Sandbox.

## The host

`ssh archz` reaches the host non-interactively; the app uses the same alias. You may run read-only commands there freely to answer questions the docs do not: `herdr api snapshot`, `herdr pane read`, `herdr agent list`, `stat`, `tail`, `ls ~/.claude/projects`, and reading Collie's source at `~/Projects/Hobby/collie` (upstream `AltanS/collie`, pinned commit in parsing.md).

The host runs the user's live work. Every Herdr pane except the scratch pane below belongs to it. Never send text or keys to, close, rename, move or start anything in those panes, and never run a mutating `herdr` command (`pane send-text`, `pane send-keys`, `agent prompt`, `agent send-keys`, `pane close`, `workspace create`, …) against them. Never run bare `herdr` (it attaches the TUI) or `herdr server stop`.

For testing sends, prompts and the terminal view, use a scratch workspace labelled `fabrikater-test`. If it does not exist, ask the user to create it (they will run `herdr workspace create --label fabrikater-test --no-focus` on the host); do not create it yourself. Anything is allowed inside that workspace, including starting `claude` in its pane.

## Conventions

- Commits: one single-line Conventional Commit subject, no body, no co-author trailer. Work that needs an "and" in its subject is two commits.
- Comment only what the code cannot say.
- Ported code from Collie keeps its MIT attribution: note the source file and commit at the top of the Swift file, and keep THIRD_PARTY_NOTICES.md current.
- Keep fixtures free of secrets and personal data before committing.
- When the docs are wrong about the host, fix the doc in the same change and say what you verified.
