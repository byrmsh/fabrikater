# When the agent's input box already holds text the app did not type, Return sends nothing and the composer says so.
e2e_launch snapshot.synthetic.json events.synthetic.jsonl claude.synthetic.jsonl requests.synthetic.jsonl \
    screen-draft.synthetic.txt=screen-w1-p1.synthetic.txt
e2e_expect_label "Synthetic refactor, Claude, Working"
e2e_key down command
e2e_expect_text "Rename the helper and run the tests"
e2e_focus_field "Message the agent"
e2e_key "Run the tests again"
e2e_key return
e2e_expect_text "already holds"
e2e_expect_text "Run the tests again"
e2e_shot send-draft
