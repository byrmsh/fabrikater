# 0006: A repo-owned macOS design skill, with a model-driven layout

Status: accepted (2026-09-25)

## Context

The vendored skills (0005) cover SwiftUI APIs, concurrency and testing, but not macOS design: menus, windows, toolbars, sidebars, keyboard, density. The user also wants two things no skill covers: IDE-style panels that can move and dock, and UI logic structured so that a later Android rewrite by agents only replaces the view layer.

The candidates found on GitHub, 2026-09-25:

- ehmo/platform-design-skills, `skills/macos` (MIT, 2026-03-18): genuinely macOS, good on menus, windows, toolbars, sidebars, keyboard and pointer; nothing on inspectors, split panes or density; one `@State` example.
- rshankras/claude-code-apple-skills, `skills/macos/ui-review-tahoe` (MIT, 2026-07-24): a macOS 26 review list; the rest of that pack is built around SwiftData and `#Preview`.
- tristan-mcinnis/apple-hig-designer-skill-2026 (MIT, 2026-03-22): all Apple platforms, mostly iOS.
- milistu/agent-skills `apple-human-interface-guidelines` (MIT claimed in the README only): a paraphrase of Apple's HIG text.
- justinwetch/HIGAgentSkills and dickwu/apple-design-skill: the best HIG coverage, but no licence, and they reproduce Apple's text. Not vendorable.

## Decision

Write `.claude/skills/macos-design/` in the repo instead of vendoring a skill:

- `SKILL.md`: fabrikater's rules. UI state, commands (`AppCommand`), shortcuts (`Keymap` of `KeyChord`s) and panel layout (`WorkspaceLayout`) are platform-neutral values in `AppModel`, tested on Linux; views only render them and dispatch commands. Native chrome, density for a developer tool, reference apps (Xcode, Zed, Tower, Finder), and a review checklist.
- `references/layout-model.md`: the panel tree, its operations and invariants, and how `AppUI` renders it.
- `references/hig-rules.md`: menus, windows, toolbar, sidebar, keyboard, pointer, notifications and accessibility, adapted from ehmo's `skills/macos/SKILL.md` under its MIT licence (kept beside it, recorded in THIRD_PARTY_NOTICES.md).
- `references/reference-apps.md`: what to take from each reference app.

## Consequences

- Design guidance matches the repo's rules and the design docs from the start, and changes with them in the same PR.
- The panel layout is a value tree rather than a docking framework: small, testable on Linux, and portable to Kotlin, at the cost of writing a split container in `AppUI` (SwiftUI's `HSplitView` cannot be driven by a model).
- `AppModel` grows `AppCommand`, `Keymap` and `WorkspaceLayout` as the milestones need them; [../structure.md](../structure.md) records the rule.
- Nothing updates automatically. If ehmo's rules improve upstream, re-adapt by hand and bump the commit in THIRD_PARTY_NOTICES.md.
