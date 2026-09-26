# The herd sidebar lists the fixture's workspaces and panes, and nothing is selected yet.
e2e_launch
e2e_expect_text "Synthetic A"
e2e_expect_text "Synthetic refactor"
e2e_expect_text "No Pane Selected"
e2e_shot sidebar
