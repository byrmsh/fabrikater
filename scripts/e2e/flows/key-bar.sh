# The key bar above the composer sends single keys to the selected pane, leaving the draft as it is.
e2e_launch snapshot.synthetic.json events.synthetic.jsonl claude.synthetic.jsonl requests.synthetic.jsonl \
    screen.synthetic.txt
e2e_key down command
e2e_expect_text "Rename the helper and run the tests"
e2e_focus_field "Message the agent"
e2e_key "Not yet"
e2e_expect_label "Escape"
e2e_expect_label "Shift-Tab"
e2e_click "Escape"
e2e_expect_text "Not yet"
e2e_expect_no_text "Herdr refused"
e2e_shot key-bar
