# The Needs You group lists the blocked Codex pane from launch; a turn that ends on another pane joins it, and ⌘2 opens
# that pane, which leaves the group.
e2e_launch
e2e_expect_label "Needs You"
e2e_expect_label "codex, Codex, Needs input"
e2e_swap_fixture snapshot-later.synthetic.json snapshot.synthetic.json
E2E_TIMEOUT=45 e2e_expect_label "Synthetic refactor, Claude, Done, Unread"
e2e_shot needs-you
e2e_key 2 command
e2e_expect_gone "Synthetic refactor, Claude, Done, Unread"
e2e_expect_label "Synthetic refactor, Claude, Done"
e2e_shot needs-you-opened
