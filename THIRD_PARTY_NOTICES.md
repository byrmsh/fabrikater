# Third-party notices

## Collie

fabrikater ports parsing logic from Collie (https://github.com/AltanS/collie, commit b7ddc17a25af76e87cd9b437053bf51821371055). The ported files are `Sources/TranscriptKit/ClaudeTranscriptParser.swift` (from `bridge/journal/claude.ts`) `Sources/TranscriptKit/TextRules.swift` (from `bridge/journal/text.ts`) and the footer phrases in `Sources/PromptKit/Dialog.swift` (from `web/src/lib/harness/claude/markers.ts`); each names its source at the top. `Tests/Fixtures/panes/` holds a selection of Collie's pane captures (`web/src/fixtures/panes/`), with the capturing user's name replaced by `User`. Collie is distributed under the following license.

```
MIT License

Copyright (c) 2026 Altan Sarisin

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Agent skills in `.claude/skills`

These agent skills are vendored for Claude Code sessions. They are not part of the app. Each directory keeps its upstream `LICENSE` file, and all four are MIT-licensed. The repository rules in CLAUDE.md take precedence over them.

| Directory | Upstream | Commit | Copyright |
|---|---|---|---|
| `swiftui-pro` | https://github.com/twostraws/SwiftUI-Agent-Skill (`swiftui-pro/`) | be297ff80dddec529af1f9b1f1f114aab6c9d11c | Copyright (c) 2026 Paul Hudson |
| `swiftui-expert-skill` | https://github.com/AvdLee/SwiftUI-Agent-Skill (`skills/swiftui-expert-skill/`) | b24e68a965dc4b5bd2cc41dc60c094a26a9379ce | Copyright (c) 2026 Antoine van der Lee |
| `swift-concurrency-pro` | https://github.com/twostraws/Swift-Concurrency-Agent-Skill (`swift-concurrency-pro/`) | bee3f69ba17142da148d3c5406f148ed62592b69 | Copyright (c) 2026 Paul Hudson |
| `swift-testing-pro` | https://github.com/twostraws/Swift-Testing-Agent-Skill (`swift-testing-pro/`) | 2d6bba14a3c8bf3694f218b92fffe617c41ae43e | Copyright (c) 2026 Paul Hudson |

The concurrency and testing skills were found through the index at https://github.com/twostraws/swift-agent-skills. Only `SKILL.md`, `references/` and, for `swiftui-expert-skill`, `scripts/` were copied. Logos and agent manifests for other tools were left out.

## Adapted rules in `.claude/skills/macos-design`

`macos-design` is fabrikater's own skill. Its `references/hig-rules.md` is adapted from `skills/macos/SKILL.md` in https://github.com/ehmo/platform-design-skills at commit dc2be825d8b439caea78e9eaa8fb3ac23b0ff3e9 (MIT, Copyright (c) 2026, the platform-design-skills authors). The licence is kept as `references/LICENSE.platform-design-skills`. Nothing else from that repository was copied (in particular not its `Apple_HIG.pdf`).

## SwiftTerm

The terminal view links SwiftTerm (https://github.com/migueldeicaza/SwiftTerm, v1.20.0) as a Swift package; its resource bundle ships inside the app. SwiftTerm is distributed under the following license.

```
Copyright (c) 2019-2026 Miguel de Icaza (https://github.com/migueldeicaza)
Copyright (c) 2017-2019, The xterm.js authors (https://github.com/xtermjs/xterm.js)
Copyright (c) 2014-2016, SourceLair Private Company (https://www.sourcelair.com)
Copyright (c) 2012-2013, Christopher Jeffrey (https://github.com/chjj/)

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
```
