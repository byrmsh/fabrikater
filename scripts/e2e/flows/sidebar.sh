# The herd sidebar names each workspace and pane for VoiceOver, with its status, and nothing is selected yet.
e2e_launch
e2e_expect_label "Synthetic A"
e2e_expect_label "fabrikater-test"
e2e_expect_label "Synthetic refactor"
e2e_expect_label "Scratch"
e2e_expect_text "Working"
e2e_expect_text "Connected"
e2e_expect_text "No Pane Selected"
e2e_shot sidebar
