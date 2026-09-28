# 0011: Our own markdown block parser instead of Textual

Status: accepted (2026-09-28)

## Context

M2 planned to render agent replies with Textual 0.5.0 ([../macos-tooling.md](../macos-tooling.md), section 4). Textual's sources use the SwiftUI State property wrapper by its SwiftUI name (`StructuredText.swift`, `BlockVStack.swift`, `Overflow.swift`), `@Entry` for its environment values and `#Preview` blocks (checked at tag 0.5.0 on 2026-09-28). Under the Command Line Tools 27 those need `libSwiftUIMacros.dylib`, which ships only with Xcode (macos-tooling.md section 1), so Textual cannot build with the user's toolchain. The `ViewState` alias only helps code we own.

Alternatives considered:

- **Pin `SDKROOT` to the 26.x SDK** for the whole build. It would let Textual compile, but ties the app to an older SDK for one dependency.
- **Fork Textual** and patch its macros. A pre-1.0 fork to keep current.
- **swiftlang/swift-markdown** for a full syntax tree, plus our own renderer. A C dependency (cmark-gfm) for a job a small parser covers.
- **A `WKWebView` transcript.** Non-native, and a much larger change.
- **Our own block parser in `AppModel`, laid out by a thin view** (chosen).

## Decision

- `AppModel/MarkdownBlocks.swift` splits a message into `MarkdownBlock`s: headings, paragraphs, lists (nesting, numbering and task boxes resolved), fenced code, quotes (parsed recursively), tables (with column alignment) and rules. It is a pure function, tested on Linux.
- Inline styling (emphasis, inline code, links) stays in each block's text; the view renders it with Foundation's inline markdown parser, as before.
- `AppUI/Conversation/MarkdownView.swift` lays the blocks out. `EntryView` uses it for every text part, except a collapsed entry, which keeps the inline-only `Text` so its line limit still works.

## Consequences

- No new dependency, and nothing added to the bundle's resources.
- No syntax highlighting in code blocks yet. It can be added to the code block's view later without touching the parser.
- Text selection works within one block at a time, not across a whole message.
- Removing it: delete the two files and the `MarkdownView` branch in `EntryView`.
