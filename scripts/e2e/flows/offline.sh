# With no snapshot to read, the sidebar says it is offline instead of showing a herd.
e2e_launch --none
e2e_expect_text "Offline"
e2e_shot offline
