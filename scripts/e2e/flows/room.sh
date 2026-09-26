# The toolbar carries the pane's status and agent, ⌃⌘S hides the sidebar, and ⌘+ enlarges the conversation's text.
e2e_launch
e2e_expect_text "Synthetic refactor"
e2e_key down command
e2e_expect_text "I'll look at the helper first."
e2e_expect_text "Claude, Working"
e2e_key s command control
e2e_expect_text_gone "Connected"
e2e_key "+" command
e2e_key "+" command
e2e_shot room
e2e_key 0 command
e2e_key s command control
e2e_expect_text "Connected"
