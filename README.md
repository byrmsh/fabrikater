# fabrikater

A native macOS app for the coding agents running in [Herdr](https://herdr.dev) on a remote Linux host. It shows Herdr's workspaces, tabs and panes in a sidebar, renders each agent's conversation locally from its session log, and sends replies and keys to the pane, all over SSH with nothing installed on the host. Start with [CLAUDE.md](CLAUDE.md) and [docs/architecture.md](docs/architecture.md).

## Run locally

You need a Mac on macOS 26.6 or later with Apple's Command Line Tools for Xcode 27 (`xcode-select --install`); Xcode is not required ([docs/macos-tooling.md](docs/macos-tooling.md)). The app runs on macOS 15 or later.

```sh
git clone https://github.com/byrmsh/fabrikater.git
cd fabrikater
scripts/bundle.sh          # release build, assembles and ad-hoc signs build/fabrikater.app
open build/fabrikater.app
```

**Against your host.** The app runs `/usr/bin/ssh <alias>` with `BatchMode=yes`, so `ssh <alias> true` must work from a terminal without a password prompt, using a host, key and any jump host from `~/.ssh/config`. The host needs `herdr` and `socat` on its non-interactive `PATH`, with the Herdr server running. The alias defaults to `arch`; set another in fabrikater › Settings… (⌘,) and press Return to switch to it, or for one run start the binary directly with `FABRIKATER_HOST`, because `open` does not pass environment variables on:

```sh
FABRIKATER_HOST=myhost build/fabrikater.app/Contents/MacOS/fabrikater
```

Release builds can send to any pane. `FABRIKATER_SEND_ALLOWLIST=label1,label2` limits sends to those workspaces, and setting it empty refuses every send ([docs/architecture.md](docs/architecture.md), "Send allowlist").

**Without a host.** Replay the checked-in fixtures instead of SSH; pane names and pins go to a separate defaults domain:

```sh
FABRIKATER_FIXTURES=Tests/Fixtures build/fabrikater.app/Contents/MacOS/fabrikater
```

**Checks only your Mac can do.** [docs/mac-checklist.md](docs/mac-checklist.md) collects every check from the merged PRs that needs the host or your eyes, in order, starting with setup.

`scripts/check.sh` runs lint, the warnings-as-errors build and the tests. A bare `swift test` fails under the Command Line Tools. If a build fails with SDK or search-path errors, retry with `FABRIKATER_BUILD_SYSTEM=native`.
