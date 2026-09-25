# fabrikater

A native macOS SwiftUI app that shows and drives coding agents running in Herdr on the Linux host `arch`, entirely over SSH. Read these before changing anything:

- [docs/architecture.md](docs/architecture.md): where every piece of data comes from and the exact host commands.
- [docs/design.md](docs/design.md): what the app looks like and how it behaves.
- [docs/parsing.md](docs/parsing.md): the session-log and prompt-screen parsing to implement, ported from Collie.
- [docs/milestones.md](docs/milestones.md): the order of work and how each milestone is checked.
- [docs/structure.md](docs/structure.md): the targets, what may depend on what, the engineering rules, and recipes for common changes.
- [docs/decisions/](docs/decisions/): why the structure, tooling and CI are the way they are.
- [docs/macos-tooling.md](docs/macos-tooling.md): building without Xcode, and the library choices.
- The `CLAUDE.md` inside each target you touch.

`scripts/check.sh` is the one check: format lint, source lint, build with warnings as errors, tests. Run it before every commit. It must stay green at every commit.

## Cloud session (Linux, CI, no host)

Cloud sessions run on Linux with no macOS, no Xcode and no access to `arch`.

- The SessionStart hook (`.claude/hooks/session-start.sh`) installs Swift 6.4 under `~/.cache/fabrikater` and puts it on `PATH`. If `swift` is missing, run the hook by hand: `CLAUDE_CODE_REMOTE=true CLAUDE_ENV_FILE=/dev/null .claude/hooks/session-start.sh`, then `export PATH="$HOME/.cache/fabrikater/swift-6.4.0/usr/bin:$PATH"`.
- On Linux, `Package.swift` leaves out `AppUI` and the `fabrikater` executable. `scripts/check.sh` builds and tests every other target. Put all logic there, test it there, and keep views thin.
- You cannot compile or see views. Review every view you write against `.claude/skills/swiftui-pro` and `.claude/skills/swiftui-expert-skill` (macOS references), and let CI's macOS job compile it.
- CI: `.github/workflows/linux.yml` runs `scripts/check.sh` on every PR. `.github/workflows/macos.yml` runs it on the `xcode-27` runner under the Command Line Tools (the user's toolchain), then `scripts/bundle.sh`, the signature check and a launch check. Read the results with the GitHub tools and drive both green.
- Never contact the host. Test against fixtures in `Tests/Fixtures/`: `*.synthetic.*` files are hand-written from the documented shapes, and real captures come from the user running `scripts/capture-fixtures.sh`. List any capture you need in the PR.
- Anything that needs the host or the user's eyes goes on the PR's "manual on the Mac" checklist, with exact commands.
- Collie's source is public: `git clone https://github.com/AltanS/collie` works read-only through the session proxy. Check out the commit pinned in parsing.md.

## Milestone sessions

Each milestone in [docs/milestones.md](docs/milestones.md) is one session and one PR. Build the first milestone that is not marked done.

- Start from the latest `main`. Present a plan first (targets and files, tests, the milestone's open questions with a recommendation) and wait for approval.
- Never push to `main`; the user merges. Work after a merge is a new PR from a fresh `main`.
- The PR description covers what was built, CI results with links, the "manual on the Mac" checklist, any capture the user must run, open questions and pushback.
- Drive both CI jobs green. Command Line Tools failures show up only in the macOS job, so push early when a change touches `Package.swift`, `AppUI`, the executable or `scripts/`. `Actions → macOS → Run workflow → toolchain: xcode` checks the Xcode path on demand.
- In the same PR, mark the milestone done in milestones.md, resolve or carry forward its open questions, and fix any doc the work proved wrong.

## Local session on the Mac

This Mac has Apple's Command Line Tools, not Xcode. Everything builds with SwiftPM from the terminal.

- `scripts/bundle.sh` builds release, assembles `build/fabrikater.app`, and ad-hoc signs it. `open build/fabrikater.app` runs it. If the default build engine fails, it retries with the native one, except under CI (`CI` set), where it fails so a broken default engine shows.
- `swift build` for a quick compile. If the default build engine fails with SDK or search-path errors, use `swift build --build-system native` (or `FABRIKATER_BUILD_SYSTEM=native scripts/check.sh`).
- Tests use swift-testing (XCTest is not available without Xcode): run `scripts/check.sh`, which adds the flags the Command Line Tools need to find swift-testing (macos-tooling.md section 1; the flags are in the script). A bare `swift test` fails under the Command Line Tools.
- Deployment target macOS 15. No App Sandbox.

### The host

`ssh arch` reaches the host non-interactively; the app uses the same alias. You may run read-only commands there freely to answer questions the docs do not: `herdr api snapshot`, `herdr pane read`, `herdr agent list`, `stat`, `tail`, `ls ~/.claude/projects`, and reading Collie's source at `~/Projects/Hobby/collie` (upstream `AltanS/collie`, pinned commit in parsing.md).

The host runs the user's live work. Every Herdr pane except the scratch pane below belongs to it. Never send text or keys to, close, rename, move or start anything in those panes, and never run a mutating `herdr` command (`pane send-text`, `pane send-keys`, `agent prompt`, `agent send-keys`, `pane close`, `workspace create`, …) against them. Never run bare `herdr` (it attaches the TUI) or `herdr server stop`.

For testing sends, prompts and the terminal view, use a scratch workspace labelled `fabrikater-test`. If it does not exist, ask the user to create it (they will run `herdr workspace create --label fabrikater-test --no-focus` on the host); do not create it yourself. Anything is allowed inside that workspace, including starting `claude` in its pane.

## Swift rules

- Never write `@State`. The macOS 27 SDK's `@State` macro needs a plugin that ships only with Xcode. Use `@ViewState`, defined once in `Sources/AppUI/ViewState.swift` as `typealias ViewState = SwiftUI.State`. Avoid `#Preview`, `@Previewable`, `@Entry` and SwiftData. `@Observable` works. `scripts/check.sh` rejects the banned forms.
- Swift 6 language mode, complete strict concurrency, zero warnings. No Combine, no bare `DispatchQueue`, no singletons outside the composition root. The full list is in [docs/structure.md](docs/structure.md), "Engineering rules".

## Skills

`.claude/skills/` holds vendored SwiftUI, Swift concurrency and Swift testing skills (licences in THIRD_PARTY_NOTICES.md). They assume Xcode and iOS, and **the repo's rules win** wherever they disagree: `@ViewState` instead of `@State`; no `#Preview`, `@Previewable`, `@Entry` or SwiftData; macOS idioms (menus, keyboard shortcuts, `NavigationSplitView`, windows and settings scenes) rather than iOS ones; the target layering in docs/structure.md.

## Conventions

- Commits: one single-line Conventional Commit subject, no body, no co-author trailer. Work that needs an "and" in its subject is two commits.
- Comment only what the code cannot say.
- Ported code from Collie keeps its MIT attribution: note the source file and commit at the top of the Swift file, and keep THIRD_PARTY_NOTICES.md current.
- Keep fixtures free of secrets and personal data before committing.
- When the docs are wrong about the host, fix the doc in the same change and say what you verified.
- A structural change (a new target, a changed dependency rule, a new tool) gets an ADR in docs/decisions/.
