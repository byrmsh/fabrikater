# Pane › Open in New Window opens the selected pane's conversation in a second window, with no sidebar, titled by the
# pane and showing its status.
e2e_launch
e2e_expect_label "Synthetic refactor, Claude, Working"
e2e_key down command
e2e_expect_text "I'll look at the helper first."
e2e_menu Pane "Open in New Window"
e2e_expect_windows 2
e2e_expect_gone "Synthetic refactor, Claude, Working"
e2e_expect_text "I'll look at the helper first."
e2e_expect_label "Claude, Working"
e2e_shot window
