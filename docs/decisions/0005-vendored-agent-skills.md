# 0005: Vendor SwiftUI, concurrency and testing skills, with repo rules on top

Status: accepted (foundation session, 2026-09-25)

## Context

Cloud agents write views they can't compile or see, so they need strong written guidance. Good MIT-licensed agent skills exist, but they assume Xcode and iOS.

## Decision

Vendor four skills into `.claude/skills/`, each with its LICENSE, and record the upstream commits in THIRD_PARTY_NOTICES.md:

- `swiftui-pro` (twostraws/SwiftUI-Agent-Skill): a compact review checklist; run it on every view.
- `swiftui-expert-skill` (AvdLee/SwiftUI-Agent-Skill): deeper references, including macOS scenes, windows and views.
- `swift-concurrency-pro` (twostraws/Swift-Concurrency-Agent-Skill): matches the strict-concurrency rules.
- `swift-testing-pro` (twostraws/Swift-Testing-Agent-Skill): the test framework used here.

twostraws/swift-agent-skills is an index of links, not skills; the last two were found through it. CLAUDE.md states that the repository's rules win over the skills: `@ViewState` instead of `@State`, no `#Preview`, `@Previewable`, `@Entry` or SwiftData, macOS idioms rather than iOS ones, and the target layering in [../structure.md](../structure.md).

## Consequences

- Every session gets the skills without installing anything.
- The copies do not update themselves. To refresh one, copy the upstream directory again and bump the commit in THIRD_PARTY_NOTICES.md.
