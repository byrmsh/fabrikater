# Settings (⌘,) holds the host, send key, notification and text size choices; an invalid host is refused, and with
# Send with ⌘Return, Return starts a new line in the composer instead of sending.
e2e_launch snapshot.synthetic.json events.synthetic.jsonl claude.synthetic.jsonl requests.synthetic.jsonl \
    screen.synthetic.txt
e2e_expect_label "Synthetic refactor, Claude, Working"
e2e_key "," command
e2e_expect_windows 2
e2e_expect_text "An alias from ~/.ssh/config. Connected to arch."
e2e_expect_text "When an agent finishes its turn"
e2e_expect_text "13 pt"
e2e_click "⌘Return"
e2e_expect_label "Return starts a new line."
e2e_focus_field "arch"
e2e_key "-bad"
e2e_expect_text "Not an ssh alias"
e2e_shot settings
e2e_key w command
e2e_expect_windows 1
e2e_key down command
e2e_expect_text "Rename the helper and run the tests"
e2e_focus_field "Message the agent"
e2e_key "First line"
e2e_key return
e2e_key "second line"
e2e_expect_focus "$(printf 'First line\nsecond line')"
e2e_shot settings-composer
