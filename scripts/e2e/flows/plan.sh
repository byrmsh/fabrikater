# A session with TodoWrite calls shows its latest plan above the conversation; one without shows none.
e2e_launch snapshot.synthetic.json events.synthetic.jsonl claude-todos.synthetic.jsonl=claude.synthetic.jsonl
e2e_expect_label "Synthetic refactor, Claude, Working"
e2e_key down command
e2e_expect_text "Writing the tests for the retry."
e2e_expect_text "2 of 4 done"
e2e_expect_text "Writing the retry tests"
e2e_expect_text "Read the uploader"
e2e_expect_no_text "A subagent's own plan"
e2e_shot plan
