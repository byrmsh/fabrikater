# Show Changes (⌥⌘0) opens an inspector listing the files the session changed, and a file expands to its diff; a
# rejected edit, one still waiting for its result and a subagent's edit are left out.
e2e_launch snapshot.synthetic.json events.synthetic.jsonl claude-changes.synthetic.jsonl=claude.synthetic.jsonl
e2e_expect_label "Synthetic refactor, Claude, Working"
e2e_key down command
e2e_expect_text "The uploader retries now. One more setting to change."
e2e_key 0 command option
e2e_expect_text "2 files"
e2e_expect_label "Uploader.swift"
e2e_expect_label "RetryTests.swift"
e2e_expect_label "5 lines added, 3 removed"
e2e_expect_no_label "README.md"
e2e_expect_no_label "Config.swift"
e2e_expect_no_label "Subagent.swift"
e2e_shot changes
e2e_disclose "Uploader.swift"
e2e_expect_text "+         try await client.send(file)"
e2e_expect_text "- let attempts = 1"
e2e_shot changes-expanded
e2e_click "Show Changes"
e2e_expect_gone "2 files"
