# An unsent draft is still in the composer after a relaunch, for the pane it was typed for.
e2e_launch snapshot.synthetic.json events.synthetic.jsonl claude.synthetic.jsonl requests.synthetic.jsonl \
    screen.synthetic.txt
e2e_key down command
e2e_expect_text "Rename the helper and run the tests"
e2e_focus_field "Message the agent"
e2e_key "Keep this for later"
e2e_expect_text "Keep this for later"
e2e_quit
E2E_KEEP_NOTES=1 e2e_launch snapshot.synthetic.json events.synthetic.jsonl claude.synthetic.jsonl \
    requests.synthetic.jsonl screen.synthetic.txt
e2e_key down command
e2e_expect_text "Keep this for later"
e2e_shot drafts
