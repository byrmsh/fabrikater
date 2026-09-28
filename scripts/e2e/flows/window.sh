# Pane › Open in New Window opens the selected pane's conversation in a second window, with no sidebar, titled by the
# pane and showing its status, and a composer that sends to that pane.
e2e_launch snapshot.synthetic.json events.synthetic.jsonl claude.synthetic.jsonl requests.synthetic.jsonl \
    screen.synthetic.txt
e2e_expect_label "Synthetic refactor, Claude, Working"
e2e_key down command
e2e_expect_text "I'll look at the helper first."
e2e_menu Pane "Open in New Window"
e2e_expect_windows 2
e2e_expect_gone "Synthetic refactor, Claude, Working"
e2e_expect_text "I'll look at the helper first."
e2e_expect_label "Claude, Working"
e2e_focus_field "Message the agent"
e2e_key "Also update the changelog"
e2e_expect_text "Also update the changelog"
e2e_shot window
e2e_key return
e2e_expect_gone "Also update the changelog"
e2e_shot window-sent
