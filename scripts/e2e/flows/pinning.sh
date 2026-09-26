# Pinning a pane adds a Pinned section on top while the pane stays in its workspace; the pin survives a relaunch.
e2e_launch
e2e_key down command
e2e_key p command shift
e2e_expect_label "Pinned"
e2e_expect_label "Synthetic A"
e2e_shot pinning
e2e_quit
E2E_KEEP_NOTES=1 e2e_launch
e2e_expect_label "Pinned"
e2e_key down command
e2e_key p command shift
e2e_expect_gone "Pinned"
e2e_shot pinning-unpinned
