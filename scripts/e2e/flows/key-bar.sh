# The key bar above the composer sends single keys to the selected pane, leaving the draft as it is.
e2e_launch snapshot.synthetic.json events.synthetic.jsonl claude.synthetic.jsonl requests.synthetic.jsonl \
    screen.synthetic.txt
e2e_key down command
e2e_expect_text "Rename the helper and run the tests"
e2e_focus_field "Message the agent"
e2e_key "Not yet"
# Found by help tag; the accessibility flow checks the names VoiceOver reads.
e2e_expect_text "Send Escape to the pane"
e2e_expect_text "Send Shift-Tab to the pane"
e2e_click "Send Escape to the pane"
e2e_expect_text "Not yet"
e2e_expect_no_text "Herdr refused"
e2e_shot key-bar
