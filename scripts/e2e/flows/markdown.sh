# An agent reply's markdown renders as blocks: a heading, numbered and nested lists, a code block, a table and a quote.
e2e_launch snapshot.synthetic.json events.synthetic.jsonl claude-markdown.synthetic.jsonl=claude.synthetic.jsonl
e2e_expect_label "Synthetic refactor, Claude, Working"
e2e_key down command
e2e_expect_label "Summary"
e2e_expect_label "2."
e2e_expect_text "gives up after 3 tries"
e2e_expect_text "try await upload()"
e2e_expect_label "Uploader.swift"
e2e_expect_label "The backoff is fixed for now."
e2e_expect_no_text "## Summary"
e2e_expect_no_text "|:-----|"
e2e_shot markdown
