# A long prompt and a compaction summary start collapsed with Show All; Show All expands one and offers Show Less.
e2e_launch snapshot.synthetic.json events.synthetic.jsonl claude-long.synthetic.jsonl=claude.synthetic.jsonl
e2e_expect_label "Synthetic refactor, Claude, Working"
e2e_key down command
e2e_expect_text "Picking up at the full test suite."
e2e_expect_label "Show All"
e2e_expect_no_text "Show Less"
e2e_shot collapse
e2e_click "Show All"
e2e_expect_label "Show Less"
e2e_shot collapse-expanded
