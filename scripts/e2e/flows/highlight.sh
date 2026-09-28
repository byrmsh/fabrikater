# Code blocks in an agent reply (claude-code.synthetic.jsonl) are highlighted per language, in light and dark mode.
e2e_launch snapshot.synthetic.json events.synthetic.jsonl claude-code.synthetic.jsonl=claude.synthetic.jsonl
e2e_expect_label "Synthetic refactor, Claude, Working"
e2e_key down command
e2e_expect_text "for attempt in 1...times { try await upload() } // backoff"
e2e_expect_text "swift test --filter \"\$SUITE\""
e2e_expect_text "+let attempts = 3"
e2e_expect_no_text '```'
e2e_shot highlight
e2e_quit
E2E_DARK=1 e2e_launch snapshot.synthetic.json events.synthetic.jsonl claude-code.synthetic.jsonl=claude.synthetic.jsonl
e2e_expect_label "Synthetic refactor, Claude, Working"
e2e_key down command
e2e_expect_text "def backoff(n: int) -> float:"
e2e_shot highlight-dark
