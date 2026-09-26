# A pane whose turn ends while it is not selected reads Unread until it is selected; the mark survives a relaunch.
e2e_launch
e2e_expect_label "Synthetic refactor, Claude, Working"
e2e_swap_fixture snapshot-later.synthetic.json snapshot.synthetic.json
E2E_TIMEOUT=45 e2e_expect_label "Synthetic refactor, Claude, Done, Unread"
e2e_shot unread
e2e_quit
E2E_KEEP_NOTES=1 e2e_launch
e2e_expect_label "Synthetic refactor, Claude, Working, Unread"
e2e_key down command
e2e_expect_label "Synthetic refactor, Claude, Working"
e2e_shot unread-read
