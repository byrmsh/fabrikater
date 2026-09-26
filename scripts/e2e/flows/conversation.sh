# Next Pane (⌘↓) selects the first pane, a Claude session, and its conversation renders from the log fixture.
e2e_launch
e2e_expect_text "Synthetic refactor"
e2e_key down command
e2e_expect_text "Rename the helper and run the tests"
e2e_expect_text "I'll look at the helper first."
e2e_shot conversation
