# Rename… (⌘⇧R) gives the selected pane a local name that replaces its label in the sidebar and the window title.
e2e_launch
e2e_expect_text "Synthetic refactor (w1:p1), Working"
e2e_key down command
e2e_expect_text "Rename the helper and run the tests"
e2e_key r command shift
e2e_key a command
e2e_key "Release notes"
e2e_shot rename-editing
e2e_key return
e2e_expect_text "Release notes (w1:p1), Working"
e2e_expect_no_text "Synthetic refactor (w1:p1), Working"
e2e_shot rename
