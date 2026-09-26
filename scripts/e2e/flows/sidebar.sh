# The herd sidebar lists the fixture's panes with their statuses, and nothing is selected yet.
e2e_launch
e2e_expect_text "Synthetic refactor (w1:p1), Working"
e2e_expect_text "Scratch (w2:p1), Done"
e2e_expect_text "Connected"
e2e_expect_text "No Pane Selected"
e2e_shot sidebar
