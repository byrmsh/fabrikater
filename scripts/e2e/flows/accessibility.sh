# What VoiceOver reads for the controls added since the sidebar's pass: the prompt card and its options, the key bar,
# the send button, the connection footer, the docked panels and the Settings steppers. Each check is a name that only
# the view's accessibility modifiers give, so a lost label fails here. accessibility-*.txt keeps the whole tree.
e2e_launch snapshot-prompt.synthetic.json events.synthetic.jsonl claude.synthetic.jsonl requests.synthetic.jsonl \
    screen-w1-p1.synthetic.txt
e2e_expect_label "Connected"
e2e_key down command
e2e_expect_text "Do you want to proceed?"
e2e_screen_dump >"${E2E_OUT}/accessibility-prompt.txt"
e2e_expect_label "Send Key"
e2e_expect_label "Escape"
e2e_expect_label "Shift-Tab"
e2e_expect_label "Yes, and don’t ask again for: rm -rf build"
e2e_expect_label "Send"
e2e_shot accessibility-prompt
e2e_quit

e2e_launch snapshot.synthetic.json events.synthetic.jsonl claude-todos.synthetic.jsonl=claude.synthetic.jsonl
e2e_expect_label "Synthetic refactor, Claude, Working"
e2e_key down command
e2e_expect_text "2 of 4 done"
e2e_key i command
e2e_expect_text "Session Info"
e2e_screen_dump >"${E2E_OUT}/accessibility-panels.txt"
e2e_key "," command
e2e_expect_windows 2
e2e_expect_text "13 pt"
e2e_screen_dump >"${E2E_OUT}/accessibility-settings.txt"
e2e_expect_label "Conversation Text Size"
e2e_expect_label "Terminal Text Size"
