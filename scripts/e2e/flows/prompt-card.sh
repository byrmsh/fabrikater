# A blocked Claude pane's permission prompt shows as a card above the composer; choosing an option sends its key.
e2e_launch snapshot-prompt.synthetic.json=snapshot.synthetic.json events.synthetic.jsonl claude.synthetic.jsonl \
    requests.synthetic.jsonl screen-w1-p1.synthetic.txt
e2e_key down command
e2e_expect_text "Permission Needed"
e2e_expect_text "Do you want to proceed?"
e2e_expect_text "rm -rf build"
# Found by help tag; the accessibility flow checks the names VoiceOver reads.
e2e_expect_text "Press 2 in the pane: Yes, and don"
e2e_shot prompt-card
e2e_click "Press 3 in the pane: No"
# The replay host keeps showing the prompt, so the card says the answer went and the prompt stayed.
e2e_expect_text "Sent “No”, but the prompt is still showing."
e2e_expect_no_text "Herdr refused"
e2e_shot prompt-card-answered
