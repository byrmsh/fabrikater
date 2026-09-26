# Typing a prompt and pressing Return sends it to the selected pane; the draft clears once Herdr took it.
e2e_launch snapshot.synthetic.json events.synthetic.jsonl claude.synthetic.jsonl requests.synthetic.jsonl \
    screen.synthetic.txt
e2e_expect_label "Synthetic refactor"
e2e_key down command
e2e_expect_text "Rename the helper and run the tests"
e2e_focus_field "Message the agent"
e2e_key "Also update the changelog"
e2e_expect_text "Also update the changelog"
e2e_shot composer-draft
e2e_key return
e2e_expect_gone "Also update the changelog"
e2e_shot composer-sent
