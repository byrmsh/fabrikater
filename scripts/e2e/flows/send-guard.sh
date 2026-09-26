# While the agent shows a permission prompt, Return sends nothing: the draft stays and the composer says why.
e2e_launch snapshot.synthetic.json events.synthetic.jsonl claude.synthetic.jsonl requests.synthetic.jsonl \
    screen-w1-p1.synthetic.txt
e2e_expect_label "Synthetic refactor"
e2e_key down command
e2e_expect_text "Rename the helper and run the tests"
e2e_focus_field "Message the agent"
e2e_key "Run the tests again"
e2e_key return
e2e_expect_text "Answer it in Herdr first"
e2e_expect_text "Run the tests again"
e2e_shot send-guard
