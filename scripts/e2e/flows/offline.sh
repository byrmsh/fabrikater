# With nothing ever read, the sidebar says it is offline and why, without claiming a last known state.
e2e_launch --none
e2e_expect_label "Offline"
e2e_expect_no_text "last known state"
e2e_shot offline
