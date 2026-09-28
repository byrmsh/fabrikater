# 0008: End-to-end flows with screenshots on the macOS CI job

Status: accepted (e2e screenshots session, 2026-09-26). Reading the tree: superseded by [0014](0014-native-e2e-accessibility-helper.md).

## Context

Cloud agents cannot compile or see views (CLAUDE.md, "Cloud session"). The macOS job only checked that the app stayed running and took one full-screen screenshot, which showed the app offline because it tried to ssh to `arch`. Agents need to see the real app with data after a change, and to know that a key flow still works.

## Decision

- **Shell flows over the bundled app.** `scripts/e2e.sh` runs each `scripts/e2e/flows/*.sh` against `build/fabrikater.app`, launched with `FABRIKATER_FIXTURES` pointing at a copy of just the fixture files the flow names. No SSH, no host.
- **Drive and check through System Events.** Keys go in with `osascript`; checks read the window's accessibility tree with JavaScript for Automation. GitHub's macOS runners grant Accessibility and Screen Recording to the shell, so no extra setup. `screencapture -R` saves only the window.
- **No test hooks in the app.** Flows use the same shortcuts a person does, so the harness tests the shipped binary and does not tangle with app code.
- **Screenshots are artifacts, not baselines.** The job uploads `build/e2e/` as `e2e-screenshots`; agents download and look at them. Text checks catch regressions; pixel comparison would break on every OS image update.

Rejected: XCUITest (needs Xcode, and the user builds with the Command Line Tools); `ImageRenderer` snapshots (renders `List` and `NavigationSplitView` as placeholders on macOS); an in-app scripting switch (app code that exists only for tests).

## Consequences

- A flow is one small file; adding or deleting one touches nothing else. docs/e2e.md is the recipe.
- A flow that fails fails the macOS job, with a failure screenshot and the app's log in the artifact.
- Flows run only on macOS; the Linux job and `scripts/check.sh` are unchanged.
