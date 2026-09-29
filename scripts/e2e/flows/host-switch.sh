# Return in Settings' host field switches hosts at once: the pane window of the old host closes, the note says the new
# host is connected, and the main window starts over on the new host's herd with nothing selected.
e2e_launch snapshot.synthetic.json events.synthetic.jsonl claude.synthetic.jsonl requests.synthetic.jsonl \
    screen.synthetic.txt
e2e_expect_label "Synthetic refactor, Claude, Working"
e2e_key down command
e2e_expect_text "I'll look at the helper first."
e2e_menu Pane "Open in New Window"
e2e_expect_windows 2
e2e_key "," command
e2e_expect_windows 3
e2e_focus_field "arch"
e2e_key "devbox"
e2e_expect_text "Connected to arch. Press Return to connect to devbox."
e2e_key return
e2e_expect_windows 2
e2e_expect_text "An alias from ~/.ssh/config. Connected to devbox."
e2e_shot host-switch-settings
e2e_key w command
e2e_expect_windows 1
e2e_expect_label "Synthetic refactor, Claude, Working"
e2e_expect_gone "I'll look at the helper first."
e2e_shot host-switch
