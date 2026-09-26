# A row shows no activity time at launch, and "now" once a later herd shows its pane changed.
e2e_launch
e2e_expect_label "Synthetic refactor, Claude, Working"
e2e_expect_no_text "Active just now"
e2e_swap_fixture snapshot-later.synthetic.json snapshot.synthetic.json
E2E_TIMEOUT=45 e2e_expect_label "Synthetic refactor, Claude, Done"
e2e_expect_label "Active just now"
e2e_shot activity
